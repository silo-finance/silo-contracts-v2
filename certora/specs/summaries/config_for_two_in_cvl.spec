/* Summarizes `SiloConfig` in CVL (early summarization) for two silos
 *
 * The implementing CVL functions are in `functions/config_for_two_functions.spec`.
 * This way they can be compared against the original functions.
 *
 * NOTE: This spec is similar to `summaries/config_for_one_in_cvl.spec` except for the
 * import.
 */

import "../functions/config_for_two_functions.spec";

methods {
    // ---- `SiloConfig` -------------------------------------------------------
    function _.getSilos() external =>  CVLGetSilos() expect (address, address);

    function _.getShareTokens(
        address _silo
    ) external => CVLGtShareTokens(_silo) expect (address, address, address);

    function _.getAssetForSilo(
        address _silo
    ) external => CVLGetAssetForSilo(_silo) expect (address);

    function _.getFeesWithAsset(
        address _silo
    ) external => CVLGetFeesWithAsset(_silo) expect (uint256, uint256, uint256, address);

    function _.getCollateralShareTokenAndAsset(
        address _silo,
        ISilo.CollateralType _collateralType
    ) external => CVLGetCollateralShareTokenAndAsset(
        _silo,
        _collateralType
    ) expect (address, address);

    function _.getDebtShareTokenAndAsset(
        address _silo
    ) external => CVLGetDebtShareTokenAndAsset(_silo) expect (address, address);
}
