using Vault0 as Vault;

methods {
    function _.balanceOf(address) external => NONDET;
    function _.convertToAssets(uint256) external => NONDET;
      
    function Vault0.redeem(uint256 shares, address receiver, address owner) external returns (uint256) envfree;
    function _.redeem(uint256 shares, address receiver, address owner) external =>
        redeem_cvl(shares, receiver, owner) expect uint256;

    // function Vault0.approve(address spender, uint256 value) external returns (bool);
    function _.approve(address spender, uint256 value) external => NONDET;
}

use builtin rule sanity;

function redeem_cvl(uint256 shares, address receiver, address owner) returns uint256 {
    return Vault.redeem(shares, receiver, owner);
}



// rule sanity_totalAssets {
//     env e;
//     totalAssets(e);
//     assert true;
//     satisfy true;
// }
