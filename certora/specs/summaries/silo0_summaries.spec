/* Summaries for single `Silo0` setup */

import "tokens_dispatchers.spec";
import "../requirements/single_silo_methods.spec";

methods {
    // ---- `envfree` ----------------------------------------------------------
        
    function Silo0.getTotalAssetsStorage(ISilo.AssetType) external returns(uint256) envfree;

    // Harness
    function Silo0.getSiloDataInterestRateTimestamp() external returns(uint64) envfree;
    function Silo0.getSiloDataDaoAndDeployerRevenue() external returns(uint192) envfree;

    // ---- Dispatcher ---------------------------------------------------------
    function _.accrueInterest() external => DISPATCHER(true);
    function _.getTotalAssetsStorage(ISilo.AssetType) external => DISPATCHER(true);
    function _.getCollateralAndProtectedTotalsStorage() external => DISPATCHER(true);

    // Accrue interest
    function _.accrueInterestForConfig(
        address, uint256, uint256
    ) external => DISPATCHER(true);

    // ---- `IHookReceiver` ----------------------------------------------------
    // Dispatching to any hook in the scene
    function _.beforeAction(address, uint256, bytes) external => DISPATCHER(true);
    function _.afterAction(address, uint256, bytes) external => DISPATCHER(true);
}
