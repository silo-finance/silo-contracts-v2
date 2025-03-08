// This is being imported in most other files. 
// Don't add anything dangerous here (like methods' summaries, etc.) !!!
// This is just for "using X as x" and envfree methods
// Don't add more "using X as x" to other files if it's already here. Reference the file instead.

using Silo0 as silo0;
using Token0 as token0;
using ShareDebtToken0 as shareDebtToken0;
using ShareProtectedCollateralToken0 as shareProtectedCollateralToken0;
using SiloConfig as siloConfig;

methods {
    // ---- `envfree` ----------------------------------------------------------
    function Token0.balanceOf(address) external returns(uint256) envfree;
    function Silo0.balanceOf(address) external returns(uint256) envfree;
    function ShareDebtToken0.balanceOf(address) external returns(uint256) envfree;
    function ShareProtectedCollateralToken0.balanceOf(
        address
    ) external returns(uint256) envfree;

    function Token0.totalSupply() external returns(uint256) envfree;
    function Silo0.totalSupply() external returns(uint256) envfree;
    function ShareDebtToken0.totalSupply() external returns(uint256) envfree;
    function ShareProtectedCollateralToken0.totalSupply() external returns(uint256) envfree;

    function Silo0.silo() external returns (address) envfree;
    function ShareDebtToken0.silo() external returns (address) envfree;
    function ShareProtectedCollateralToken0.silo() external returns (address) envfree;

    function Silo0.siloConfig() external returns (address) envfree;
    function ShareDebtToken0.siloConfig() external returns (address) envfree;
    function ShareProtectedCollateralToken0.siloConfig() external returns (address) envfree;

    function Silo0.config() external returns (address) envfree;
} 