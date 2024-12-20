// This is being imported in most other files. 
// Don't add anything dangerous here (like methods' summaries, etc.) !!!
// This is just for "using X as x" and envfree methods
// Don't add more "using X as x" to other files if it's already here. Reference the file instead.

import "single_silo_methods.spec";

using Silo1 as silo1;
using Token1 as token1;
using ShareDebtToken1 as shareDebtToken1;
using ShareProtectedCollateralToken1 as shareProtectedCollateralToken1;

methods {
    // ---- `envfree` ----------------------------------------------------------
    function Token1.balanceOf(address) external returns(uint256) envfree;
    function Silo1.balanceOf(address) external returns(uint256) envfree;
    function ShareDebtToken1.balanceOf(address) external returns(uint256) envfree;
    function ShareProtectedCollateralToken1.balanceOf(
        address
    ) external returns(uint256) envfree;

    function Token1.totalSupply() external returns(uint256) envfree;
    function Silo1.totalSupply() external returns(uint256) envfree;
    function ShareDebtToken1.totalSupply() external returns(uint256) envfree;
    function ShareProtectedCollateralToken1.totalSupply() external returns(uint256) envfree;

    function Silo1.silo() external returns (address) envfree;
    function ShareDebtToken1.silo() external returns (address) envfree;
    function ShareProtectedCollateralToken1.silo() external returns (address) envfree;

    function Silo1.siloConfig() external returns (address) envfree;
    function ShareDebtToken1.siloConfig() external returns (address) envfree;
    function ShareProtectedCollateralToken1.siloConfig() external returns (address) envfree;

    function Silo1.config() external returns (address) envfree;
} 