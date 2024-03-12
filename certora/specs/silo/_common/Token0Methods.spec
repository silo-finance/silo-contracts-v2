using Token0 as token0;

methods {
    function token0.balanceOf(address) external returns(uint256) envfree;
    function token0.totalSupply() external returns(uint256) envfree;
}

// https://github.com/Certora/tutorials-code/blob/master/lesson4_invariants/erc20/total_supply.spec#L57
ghost mapping(address => uint256) token0BalanceOfMirror {
    init_state axiom forall address a. token0BalanceOfMirror[a] == 0;
}

ghost mathint sumBalancesToken0 {
    init_state axiom sumBalancesToken0 == 0;
    axiom forall address a. forall address b. (
        (a != b => sumBalancesToken0 >= token0BalanceOfMirror[a] + token0BalanceOfMirror[b])
    );
    axiom forall address a. forall address b. forall address c. (
        (a != b && a != c && b != c) => 
        sumBalancesToken0 >= token0BalanceOfMirror[a] + token0BalanceOfMirror[b] + token0BalanceOfMirror[c]
    );
}

hook Sstore token0._balances[KEY address user] uint256 newBalance (uint256 oldBalance) {
    sumBalancesToken0 = sumBalancesToken0 + newBalance - oldBalance;
    token0BalanceOfMirror[user] = newBalance;
}

hook Sload uint256 balance token0._balances[KEY address user] {
    require token0BalanceOfMirror[user] == balance;
}

function requireToken0TotalAndBalancesIntegrity() {
    require to_mathint(token0.totalSupply()) == sumBalancesToken0;
}
