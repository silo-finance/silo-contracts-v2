use builtin rule sanity;

methods {
    function _.getCollateralAndProtectedAssets() external => DISPATCHER(true);
    function _.total(ISiloMock.AssetType) external => DISPATCHER(true);
    function _.getCollateralAndDebtAssets() external => DISPATCHER(true);
}