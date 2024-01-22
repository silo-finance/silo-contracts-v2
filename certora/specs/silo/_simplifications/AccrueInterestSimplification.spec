methods {
    function Silo._accrueInterest()
        internal
        returns (uint256, ISiloConfig.ConfigData memory) => simplified_accrueInterest();
}

function simplified_accrueInterest() returns (uint256, ISiloConfig.ConfigData) {
    ISiloConfig.ConfigData config = siloConfig.getConfig(silo0);
    uint256 anyInterest;

    return (anyInterest, config);
}
