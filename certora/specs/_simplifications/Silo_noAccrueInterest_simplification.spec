methods {
    function Silo._accrueInterest()
        internal
        returns (uint256, address) => accrueInterest_noStateChange();

    function Silo._callAccrueInterestForAsset(address _interestRateModel, uint256 _daoFee, uint256 _deployerFee)
        internal
        returns (uint256) => callAccrueInterestForAsset_noStateChange(_interestRateModel, _daoFee, _deployerFee);
}

function accrueInterest_noStateChange() returns (uint256, address siloConfig) {
    ISiloConfig.ConfigData config = siloConfig.getConfig(silo0);
    uint256 anyInterest;

    return (anyInterest, siloConfig);
}

function callAccrueInterestForAsset_noStateChange(address _interestRateModel, uint256 _daoFee, uint256 _deployerFee)
    returns uint256
{
    uint256 anyInterest;
    return anyInterest;
}
