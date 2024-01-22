using Token0 as token0;

methods {
    function token0.balanceOf(address) external returns(uint256) envfree;
    function token0.totalSupply() external returns(uint256) envfree;
}

// https://github.com/Certora/tutorials-code/blob/master/lesson4_invariants/erc20/total_supply.spec#L57
ghost mapping(address => uint256) balanceOfMirror {
    init_state axiom forall address a. balanceOfMirror[a] == 0;
}

ghost mathint sumBalances {
    init_state axiom sumBalances == 0;
    axiom forall address a. forall address b. (
        (a != b => sumBalances >= balanceOfMirror[a] + balanceOfMirror[b])
    );
    axiom forall address a. forall address b. forall address c. (
        (a != b && a != c && b != c) => 
        sumBalances >= balanceOfMirror[a] + balanceOfMirror[b] + balanceOfMirror[c]
    );
}

hook Sstore token0._balances[KEY address user] uint256 newBalance (uint256 oldBalance) STORAGE
{
    sumBalances = sumBalances + newBalance - oldBalance;
    balanceOfMirror[user] = newBalance;
}

invariant mirrorIsTrue(address a)
    balanceOfMirror[a] == token0.balanceOf(a);


invariant totalIsSumBalances()
    to_mathint(token0.totalSupply()) == sumBalances
    {
        preserved transfer(address recipient, uint256 amount) with (env e1) {
            requireInvariant mirrorIsTrue(recipient);
            requireInvariant mirrorIsTrue(e1.msg.sender);
        }
        preserved transferFrom(
            address sender, address recipient, uint256 amount
        ) with (env e2) {
            requireInvariant mirrorIsTrue(sender);
            requireInvariant mirrorIsTrue(recipient);
            requireInvariant mirrorIsTrue(e2.msg.sender);
        }
    }

function requireToken0Balances() {
    require to_mathint(token0.totalSupply()) == sumBalancesCollateral;
}
