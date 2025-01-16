using Vault0 as Vault;

methods {
    // TODO: put something more concrete here? patch to Vault0?  look for more candidates ..
    //  perhaps a standard ERC20 impl
    function _.balanceOf(address a) external => DISPATCHER(true); 
    // unresolved external in _.balanceOf(address a) => DISPATCH [  ] default Vault.balanceOf(a); 
    function _.convertToAssets(uint256) external => DISPATCHER(true);
      
//     function Vault0.redeem(uint256 shares, address receiver, address owner) external returns (uint256) envfree;
    function _.redeem(uint256 shares, address receiver, address owner) external => DISPATCHER(true); 

//         redeem_cvl(shares, receiver, owner) expect uint256;

    // function Vault0.approve(address spender, uint256 value) external returns (bool);

    function _.approve(address spender, uint256 value) external => DISPATCHER(true);
    function _.deposit(uint256, address) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.asset() external => DISPATCHER(true);
    function _.withdraw(uint256,address,address) external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);
    function _.maxDeposit(address) external => DISPATCHER(true); // DISPATCH [ Vault._ ] default unreachable(); // DISPATCHER(true);
    function _.maxWithdraw(address) external => DISPATCHER(true);
}


function assumeFalse() {
    require(false); // optimistic .. 
}

use builtin rule sanity;

//function redeem_cvl(uint256 shares, address receiver, address owner) returns uint256 {
//    return Vault.redeem(shares, receiver, owner);
//}



// rule sanity_totalAssets {
//     env e;
//     totalAssets(e);
//     assert true;
//     satisfy true;
// }
