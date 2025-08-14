

/* The base spec file containing methods declaration and summaries used in all leverage verification files.
This file is imported by other spec files. 
*/

using TrustedSilo0 as silo0;
using TrustedSilo1 as silo1;
using SimpleDebtToken0 as debtToken0;
using SimpleDebtToken1 as debtToken1;
using SimpleCollateralToken0 as collateralToken0;
using SimpleCollateralToken1 as collateralToken1;
using WETH as weth;
using GeneralSwapModule as generalSwapModule;

using Token0Permit as token0;
using Token1Permit as token1;


methods {
    //envfree functions 
    function token0.balanceOf(address) external returns (uint256) envfree;
    function token1.balanceOf(address) external returns (uint256) envfree;
    function collateralToken0.balanceOf(address) external returns (uint256) envfree;
    function collateralToken1.balanceOf(address) external returns (uint256) envfree;
    function debtToken0.balanceOf(address) external returns (uint256) envfree;
    function debtToken1.balanceOf(address) external returns (uint256) envfree;
    function silo0.balanceOf(address) external returns (uint256) envfree;
    function silo1.balanceOf(address) external returns (uint256) envfree;
    function weth.balanceOf(address) external returns (uint256) envfree;
    function weth.allowance(address,address) external returns (uint256) envfree;
    function token0.allowance(address,address) external returns (uint256) envfree;
    function token1.allowance(address,address) external returns (uint256) envfree;
    function silo0.allowance(address,address) external returns (uint256) envfree;
    function silo1.allowance(address,address) external returns (uint256) envfree;
    function collateralToken0.allowance(address,address) external returns (uint256) envfree;
    function collateralToken1.allowance(address,address) external returns (uint256) envfree;
    function debtToken0.allowance(address,address) external returns (uint256) envfree;
    function debtToken1.allowance(address,address) external returns (uint256) envfree;


    // view functions that are safe over-approximated
    function _.config() external => NONDET; 
    function _.getSilos() external => NONDET;
    function _.calculateLeverageFee(uint256 _amount) internal => NONDET; 

    // erc20 calls 
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.totalSupply() external => DISPATCHER(true);
    function _.allowance(address owner, address spender) external  => DISPATCHER(true);
    function _.approve(address spender, uint256 value) external  => DISPATCHER(true);
    function _.permit(address owner, address spender, uint256 value, uint256 deadline,
        uint8 v, bytes32 r, bytes32 s) external => DISPATCHER(true);

    // silo calls
    function _.flashLoan(address _receiver, address _token, uint256 _amount, bytes _data) external => DISPATCHER(true);
    function _.repayShares(uint256 _shares, address _borrower) external => DISPATCHER(true);
    function _.redeem(uint256 _shares, address _receiver, address _owner, ISilo.CollateralType _collateralType) external => DISPATCHER(true);    
    function _.deposit(uint256 _assets, address _receiver, ISilo.CollateralType _collateralType) external => DISPATCHER(true);
    function _.borrow(uint256 _assets, address _receiver, address _borrower) external => DISPATCHER(true);
    function _.asset() external => DISPATCHER(true); 
    function _.maxRepay(address _borrower) external => DISPATCHER(true);

    // A safe over-approximation that reflect both trusted pairs and untrusted pairs
    function _._resolveOtherSilo(address _thisSilo) internal  => resolveOtherCVL(_thisSilo) expect (address);
    function _.getShareTokens(address _silo) external => getShareTokensCVL(_silo) expect (address, address, address);

    //router
    function _.predictUserLeverageContract(address user) external => uniqueUserLeverageContract(user) expect (address);
}

ghost uniqueUserLeverageContract(address) returns address {
  axiom forall address u1. forall address u2.  uniqueUserLeverageContract(u1) == uniqueUserLeverageContract(u2) => u1 == u2;
}

function resolveOtherCVL(address _silo) returns address {
  address anySilo;
  if(_silo == silo0) { 
    return silo1; } 
  else if(_silo == silo1) { 
    return silo0; }
  else
    return anySilo;
}

// returns (address protectedShareToken, address collateralShareToken, address debtShareToken)
function getShareTokensCVL(address _silo) returns (address, address, address)
    {
        address anyToken1;
        address anyToken2;
        address anyToken3;
        if (_silo == silo0) {
            return (collateralToken0, silo0, debtToken0);
        } else if (_silo == silo1) {
            return (collateralToken1, silo1, debtToken1);
        } else {
            return (anyToken1, anyToken2, anyToken3);
        }
    }

/* 
Function that no need to check as top level.
Function onFlashLoan() is proved to revert as top level.
Functions closeLeveragePositionPermit() and openLeveragePositionPermit() are assumed as equivalent to  
closeLeveragePosition() and openLeveragePosition() respectively. 
*/
definition filteredFunctions(method f) returns bool =
        f.selector == sig:onFlashLoan(address,address,uint256,uint256,bytes).selector ||
        f.selector == sig:closeLeveragePositionPermit(address,bytes,ILeverageUsingSiloFlashloan.CloseLeverageArgs, ILeverageUsingSiloFlashloan.Permit ).selector ||
        f.selector == sig:openLeveragePositionPermit(address,ILeverageUsingSiloFlashloan.FlashArgs,bytes,
                                    ILeverageUsingSiloFlashloan.DepositArgs,ILeverageUsingSiloFlashloan.Permit).selector ;



