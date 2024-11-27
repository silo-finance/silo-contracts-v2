/* Requirement functions for a setup with the various tokens 
 *
 * NOTE: this spec assumes that `Silo0` is the collateral share token.
 * NOTE: Requires `silo0()` and `siloConfig()` to be `envfree`.

 * This file is being imported in most other files. 
 * Don't add anything dangerous here (like methods' summaries, etc.) !!!

 * Add more requirements on silo0s' tokens here if needed (as a functions that can be called in rules)
 */

import "single_silo_methods.spec";

// ---- Functions --------------------------------------------------------------

// @title Prevents having block timestamp less than interest rate timestamp
function silosTimestampSetupRequirements(env e) {
    require require_uint64(e.block.timestamp) >= silo0.getSiloDataInterestRateTimestamp(e);
}

// @title Given address is not one of the tokens, silos or config
function nonSceneAddressRequirements(address sender) {
    require sender != silo0;
    require sender != siloConfig;

    require sender != shareDebtToken0;
    require sender != shareProtectedCollateralToken0;

    require sender != token0;
}

// @title Ensures the `siloConfig` is set up properly
function configForEightTokensSetupRequirements() {
    require silo0.silo() == silo0;
    require silo0.config() == siloConfig;

    require shareDebtToken0.silo() == silo0;
    require shareProtectedCollateralToken0.silo() == silo0;
    
    require silo0.siloConfig() == siloConfig;
    require shareDebtToken0.siloConfig() == siloConfig;
    require shareDebtToken0.siloConfig() == siloConfig;
}

function totalSuppliesMoreThanBalances(address user1, address user2) {
    require user1 != user2;
    require (
        to_mathint(silo0.totalSupply()) >=
        silo0.balanceOf(user1) + silo0.balanceOf(user2)
    );
    require (
        to_mathint(shareDebtToken0.totalSupply()) >=
        shareDebtToken0.balanceOf(user1) + shareDebtToken0.balanceOf(user2)
    );
    require (
        to_mathint(shareProtectedCollateralToken0.totalSupply()) >=
        shareProtectedCollateralToken0.balanceOf(user1) +
        shareProtectedCollateralToken0.balanceOf(user2)
    );
    require (
        to_mathint(token0.totalSupply()) >=
        token0.balanceOf(user1) + token0.balanceOf(user2)
    );
}

function totalSuppliesMoreThanThreeBalances(address user1, address user2, address user3) {
    require user1 != user2 && user1 != user3 && user2 != user3;
    require (
        to_mathint(silo0.totalSupply()) >=
        silo0.balanceOf(user1) + silo0.balanceOf(user2) + silo0.balanceOf(user3)
    );
    require (
        to_mathint(shareDebtToken0.totalSupply()) >=
        shareDebtToken0.balanceOf(user1) +
        shareDebtToken0.balanceOf(user2) +
        shareDebtToken0.balanceOf(user3)
    );
    require (
        to_mathint(shareProtectedCollateralToken0.totalSupply()) >=
        shareProtectedCollateralToken0.balanceOf(user1) +
        shareProtectedCollateralToken0.balanceOf(user2) +
        shareProtectedCollateralToken0.balanceOf(user3)
    );
    require (
        to_mathint(token0.totalSupply()) >=
        token0.balanceOf(user1) + token0.balanceOf(user2) + token0.balanceOf(user3)
    );
}
