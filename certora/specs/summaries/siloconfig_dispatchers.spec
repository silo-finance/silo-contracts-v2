/* Summaries for `SiloConfig` - mainly dispatcher */

methods {
    // ---- `envfree` ----------------------------------------------------------
    function SiloConfig.accrueInterestForSilo(address) external envfree;
    function SiloConfig.getCollateralShareTokenAndAsset(
        address,
        ISilo.CollateralType
    ) external returns (address, address) envfree;

    // ---- Dispatcher ---------------------------------------------------------
    function _.accrueInterestForSilo(address) external => DISPATCHER(true);
    function _.accrueInterestForBothSilos() external => DISPATCHER(true);
    function _.getConfigsForWithdraw(address,address) external => DISPATCHER(true);
    function _.getConfigsForBorrow(address) external  => DISPATCHER(true);
    function _.getConfigsForSolvency(address) external  => DISPATCHER(true);
    function _.getCollateralShareTokenAndAsset(
        address,
        ISilo.CollateralType
    ) external => DISPATCHER(true);

    function _.hasDebtInOtherSilo(address,address) external  => DISPATCHER(true);
    function _.setThisSiloAsCollateralSilo(address) external  => DISPATCHER(true);
    function _.setOtherSiloAsCollateralSilo(address) external  => DISPATCHER(true);
    function _.getConfig(address) external  => DISPATCHER(true);
    function _.getFeesWithAsset(address) external  => DISPATCHER(true);
    function _.borrowerCollateralSilo(address) external  => DISPATCHER(true);
    function _.onDebtTransfer(address,address) external  => DISPATCHER(true);
    function _.getDebtShareTokenAndAsset(address) external  => DISPATCHER(true);

    // `CrossReentrancyGuard`
    function _.turnOnReentrancyProtection() external => DISPATCHER(true);
    function _.turnOffReentrancyProtection() external => DISPATCHER(true);
}
