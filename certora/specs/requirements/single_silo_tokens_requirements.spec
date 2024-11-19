/* Requirement functions for a setup with the various tokens 
 *
 * NOTE: this spec assumes that `Silo0` is the collateral share token.
 * NOTE: Requires `silo0()` and `siloConfig()` to be `envfree`.
 */

// To keep the contract aliases unique, we added the suffix `_R` (for requirements)
using Silo0 as silo0_R;

using SiloConfig as siloConfig_R;

using ShareDebtToken0 as shareDebtToken0_R;
using ShareProtectedCollateralToken0 as shareProtectedCollateralToken0_R;

using Token0 as token0_R;

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

// ---- Functions --------------------------------------------------------------

/// @title Prevents having block timestamp less than interest rate timestamp
function silosTimestampSetupRequirements(env e) {
    require require_uint64(e.block.timestamp) >= silo0_R.getSiloDataInterestRateTimestamp(e);
}


/// @title Given address is not one of the tokens, silos or config
function nonSceneAddressRequirements(address sender) {
    require sender != silo0_R;
    require sender != siloConfig_R;

    require sender != shareDebtToken0_R;
    require sender != shareProtectedCollateralToken0_R;

    require sender != token0_R;
}


/// @title Ensures the `siloConfig` is set up properly
function configForEightTokensSetupRequirements() {
    require silo0_R.silo() == silo0_R;
    require silo0_R.config() == siloConfig_R;

    require shareDebtToken0_R.silo() == silo0_R;
    require shareProtectedCollateralToken0_R.silo() == silo0_R;
    
    require silo0_R.siloConfig() == siloConfig_R;
    require shareDebtToken0_R.siloConfig() == siloConfig_R;
    require shareDebtToken0_R.siloConfig() == siloConfig_R;
}


function totalSuppliesMoreThanBalances(address user1, address user2) {
    require user1 != user2;
    require (
        to_mathint(silo0_R.totalSupply()) >=
        silo0_R.balanceOf(user1) + silo0_R.balanceOf(user2)
    );
    require (
        to_mathint(shareDebtToken0_R.totalSupply()) >=
        shareDebtToken0_R.balanceOf(user1) + shareDebtToken0_R.balanceOf(user2)
    );
    require (
        to_mathint(shareProtectedCollateralToken0_R.totalSupply()) >=
        shareProtectedCollateralToken0_R.balanceOf(user1) +
        shareProtectedCollateralToken0_R.balanceOf(user2)
    );
    require (
        to_mathint(token0_R.totalSupply()) >=
        token0_R.balanceOf(user1) + token0_R.balanceOf(user2)
    );
}


function totalSuppliesMoreThanThreeBalances(address user1, address user2, address user3) {
    require user1 != user2 && user1 != user3 && user2 != user3;
    require (
        to_mathint(silo0_R.totalSupply()) >=
        silo0_R.balanceOf(user1) + silo0_R.balanceOf(user2) + silo0_R.balanceOf(user3)
    );
    require (
        to_mathint(shareDebtToken0_R.totalSupply()) >=
        shareDebtToken0_R.balanceOf(user1) +
        shareDebtToken0_R.balanceOf(user2) +
        shareDebtToken0_R.balanceOf(user3)
    );
    require (
        to_mathint(shareProtectedCollateralToken0_R.totalSupply()) >=
        shareProtectedCollateralToken0_R.balanceOf(user1) +
        shareProtectedCollateralToken0_R.balanceOf(user2) +
        shareProtectedCollateralToken0_R.balanceOf(user3)
    );
    require (
        to_mathint(token0_R.totalSupply()) >=
        token0_R.balanceOf(user1) + token0_R.balanceOf(user2) + token0_R.balanceOf(user3)
    );
}
