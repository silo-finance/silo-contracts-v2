/* Checks equivalence of `SiloConfig` summarized functions from 
 * `functions/config_for_two_functions.spec`.
 *
 * NOTE: This spec is the same as `meta/config_for_one_equivalence.spec` except for
 * the import.
 */

import "../functions/config_for_two_functions.spec";
import "../requirements/tokens_requirements.spec";

methods {
    // ---- `SiloConfig` -------------------------------------------------------
    function getSilos() external returns (address, address) envfree;
    function getShareTokens(address) external returns (address, address, address) envfree;
    function getAssetForSilo(address) external returns (address) envfree;
    function getFeesWithAsset(
        address
    ) external returns (uint256, uint256, uint256, address) envfree;
    function getCollateralShareTokenAndAsset(
        address,
        ISilo.CollateralType
    ) external returns (address, address) envfree;
    function getDebtShareTokenAndAsset(address) external returns (address, address) envfree;
}

// ---- Rules ------------------------------------------------------------------

/// @title For testing the setup
rule sanityWithSetup_borrow() {
    calldataarg args;
    env e; 
    configForEightTokensSetupRequirements();
    nonSceneAddressRequirements(e.msg.sender);
    silosTimestampSetupRequirements(e);
    silo0_R.borrow(e, args);
    satisfy true;
}

rule getSilosEquivalence() {
    address s0;
    address s1;
    s0, s1 = getSilos();

    address c0;
    address c1;
    c0, c1 = CVLGetSilos();

    assert (s0 == c0 && s1 == c1, "getSilos equivalent to CVLGetSilos");
}


rule getShareTokensEquivalence(address _silo) {
    address protected;
    address collateral;
    address debt;
    protected, collateral, debt = getShareTokens(_silo);

    address protected_cvl;
    address collateral_cvl;
    address debt_cvl;
    protected_cvl, collateral_cvl, debt_cvl = CVLGtShareTokens(_silo);

    assert (
        protected == protected_cvl && collateral == collateral_cvl && debt == debt_cvl,
        "getShareTokens equivalent to CVLGtShareTokens"
    );
}


rule getAssetForSiloEquivalence(address _silo) {
    assert (
        getAssetForSilo(_silo) == CVLGetAssetForSilo(_silo),
        "getAssetForSilo equivalent to CVLGetAssetForSilo"
    );
}


rule getFeesWithAssetEquivalence(address _silo) {
    uint256 dao_fee;
    uint256 deployer_fee;
    uint256 flash_fee;
    address token;
    dao_fee, deployer_fee, flash_fee, token = getFeesWithAsset(_silo);

    uint256 dao_fee_cvl;
    uint256 deployer_fee_cvl;
    uint256 flash_fee_cvl;
    address token_cvl;
    dao_fee_cvl, deployer_fee_cvl, flash_fee_cvl, token_cvl = CVLGetFeesWithAsset(_silo);

    assert (
        dao_fee == dao_fee_cvl &&
        deployer_fee == deployer_fee_cvl &&
        flash_fee == flash_fee_cvl &&
        token == token_cvl,
        "getFeesWithAsset equivalent to CVLGetFeesWithAsset"
    );
}


rule getCollateralShareTokenAndAssetEquivalence(
    address _silo,
    ISilo.CollateralType _collateralType
) {
    address share;
    address token;
    share, token = getCollateralShareTokenAndAsset(_silo, _collateralType);

    address share_cvl;
    address token_cvl;
    share_cvl, token_cvl = CVLGetCollateralShareTokenAndAsset(_silo, _collateralType);

    assert (
        share == share_cvl && token == token_cvl,
        "getCollateralShareTokenAndAsset equivalent to CVLGetCollateralShareTokenAndAsset"
    );
}


rule getDebtShareTokenAndAssetEquivalence(address _silo) {
    address debt;
    address token;
    debt, token = getDebtShareTokenAndAsset(_silo);

    address debt_cvl;
    address token_cvl;
    debt_cvl, token_cvl = CVLGetDebtShareTokenAndAsset(_silo);
    assert (
        debt == debt_cvl && token == token_cvl,
        "getDebtShareTokenAndAsset equivalent to CVLGetDebtShareTokenAndAsset"
    );
}
