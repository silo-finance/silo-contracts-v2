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

    function shareProtectedCollateralToken0.name() internal returns(string memory) => simplified_name();
    function shareDebtToken0.name() internal returns(string memory) => simplified_name();
    function shareCollateralToken0.name() internal returns(string memory) => simplified_name();

    function shareProtectedCollateralToken0.symbol() internal returns(string memory) => simplified_symbol();
    function shareDebtToken0.symbol() internal returns(string memory) => simplified_symbol();
    function shareCollateralToken0.symbol() internal returns(string memory) => simplified_symbol();
}

// https://github.com/Certora/tutorials-code/blob/master/lesson4_invariants/erc20/total_supply.spec#L57
// Collateral token
ghost mapping(address => uint256) balanceOfMirrorCollateral {
    init_state axiom forall address a. balanceOfMirrorCollateral[a] == 0;
}

ghost mathint sumBalancesCollateral {
    init_state axiom sumBalancesCollateral == 0;
    axiom forall address a. forall address b. (
        (a != b => sumBalancesCollateral >= balanceOfMirrorCollateral[a] + balanceOfMirrorCollateral[b])
    );
    axiom forall address a. forall address b. forall address c. (
        (a != b && a != c && b != c) => 
        sumBalancesCollateral >= balanceOfMirrorCollateral[a] + balanceOfMirrorCollateral[b] + balanceOfMirrorCollateral[c]
    );
}

hook Sstore shareCollateralToken0._balances[KEY address user] uint256 newBalance (uint256 oldBalance) STORAGE {
    sumBalancesCollateral = sumBalancesCollateral + newBalance - oldBalance;
    balanceOfMirrorCollateral[user] = newBalance;
}

// Protected collateral token
ghost mapping(address => uint256) balanceOfMirrorProtected {
    init_state axiom forall address a. balanceOfMirrorProtected[a] == 0;
}

ghost mathint sumBalancesProtected {
    init_state axiom sumBalancesProtected == 0;
    axiom forall address a. forall address b. (
        (a != b => sumBalancesProtected >= balanceOfMirrorProtected[a] + balanceOfMirrorProtected[b])
    );
    axiom forall address a. forall address b. forall address c. (
        (a != b && a != c && b != c) => 
        sumBalancesProtected >= balanceOfMirrorProtected[a] + balanceOfMirrorProtected[b] + balanceOfMirrorProtected[c]
    );
}

hook Sstore shareProtectedCollateralToken0._balances[KEY address user] uint256 newBalance (uint256 oldBalance) STORAGE {
    sumBalancesProtected = sumBalancesProtected + newBalance - oldBalance;
    balanceOfMirrorProtected[user] = newBalance;
}

// Debt token
ghost mapping(address => uint256) balanceOfMirrorDebt {
    init_state axiom forall address a. balanceOfMirrorDebt[a] == 0;
}

ghost mathint sumBalancesDebt {
    init_state axiom sumBalancesDebt == 0;
    axiom forall address a. forall address b. (
        (a != b => sumBalancesDebt >= balanceOfMirrorDebt[a] + balanceOfMirrorDebt[b])
    );
    axiom forall address a. forall address b. forall address c. (
        (a != b && a != c && b != c) => 
        sumBalancesDebt >= balanceOfMirrorDebt[a] + balanceOfMirrorDebt[b] + balanceOfMirrorDebt[c]
    );
}

hook Sstore shareDebtToken0._balances[KEY address user] uint256 newBalance (uint256 oldBalance) STORAGE {
    sumBalancesDebt = sumBalancesDebt + newBalance - oldBalance;
    balanceOfMirrorDebt[user] = newBalance;
}

function requireShareProtectedCollateralToken0Balances() {
    require to_mathint(shareProtectedCollateralToken0.totalSupply()) == sumBalancesProtected;
}

function requireShareDebtToken0Balances() {
    require to_mathint(shareDebtToken0.totalSupply()) == sumBalancesDebt;
}

function requireShareCollateralToken0Balances() {
    require to_mathint(shareCollateralToken0.totalSupply()) == sumBalancesCollateral;
}
