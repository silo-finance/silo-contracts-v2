import "silo0_summaries.spec";
import "../requirements/two_silos_methods.spec";

/* Summaries for two silos setup */

// TODO - rename file to silo1_envfree as no summaries here 

methods {
    // ---- `envfree` ----------------------------------------------------------
    function Silo1.config() external returns (address) envfree;
    function Silo1.getTotalAssetsStorage(ISilo.AssetType) external returns(uint256) envfree;

    // Harness
    function Silo1.getSiloDataInterestRateTimestamp() external returns(uint64) envfree;
    function Silo1.getSiloDataDaoAndDeployerRevenue() external returns(uint192) envfree;

}
