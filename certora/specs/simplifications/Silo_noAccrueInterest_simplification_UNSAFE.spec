methods {
    function Silo._accrueInterest()
        internal
        returns (uint256) => accrueInterest_noStateChange();

    function Silo._accrueInterestForAsset(address _interestRateModel, uint256 _daoFee, uint256 _deployerFee)
        internal
        returns (uint256) => callAccrueInterestForAsset_noStateChange(_interestRateModel, _daoFee, _deployerFee);
}

function accrueInterest_noStateChange() returns uint256 {
    uint256 anyInterest;
    return anyInterest;
}

function callAccrueInterestForAsset_noStateChange(address _interestRateModel, uint256 _daoFee, uint256 _deployerFee)
    returns uint256
{
    uint256 anyInterest;
    return anyInterest;
}
