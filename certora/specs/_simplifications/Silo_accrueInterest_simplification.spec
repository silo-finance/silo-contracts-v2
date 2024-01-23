methods {
    function Silo._accrueInterest()
        internal
        returns (uint256, ISiloConfig.ConfigData memory) => accrueInterest_noStateChange();
}

function accrueInterest_noStateChange() returns (uint256, ISiloConfig.ConfigData) {
    ISiloConfig.ConfigData config = siloConfig.getConfig(silo0);
    uint256 anyInterest;

    return (anyInterest, config);
}
