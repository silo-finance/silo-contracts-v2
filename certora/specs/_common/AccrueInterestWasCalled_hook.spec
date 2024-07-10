import "SiloMethods.spec";
// Hooks to call of _callAccrueInterestForAsset. Logs whether the method was called or not.

methods 
{
    function Silo._callAccrueInterestForAsset(address _interestRateModel,
        uint256 _daoFee, uint256 _deployerFee, address _otherSilo) internal 
        returns (uint256) with (env e) => callAccrueInterestForAsset_Summary(e, calledContract, 
            _interestRateModel, _daoFee, _deployerFee, _otherSilo);
    function Silo._callAccrueInterestForAsset_orig(address _interestRateModel,
        uint256 _daoFee, uint256 _deployerFee, address _otherSilo) external 
        returns (uint256);
}

ghost bool wasAccrueInterestCalled_silo0 
{
    init_state axiom wasAccrueInterestCalled_silo0 == false;
}

ghost bool wasAccrueInterestCalled_silo1 
{
    init_state axiom wasAccrueInterestCalled_silo1 == false;
}

function callAccrueInterestForAsset_Summary(env e, address siloContract,
        address _interestRateModel,
        uint256 _daoFee,
        uint256 _deployerFee,
        address _otherSilo) 
    returns uint256
{
    if (siloContract == silo0)
    {
        wasAccrueInterestCalled_silo0 = true;
        uint256 interest = silo0._callAccrueInterestForAsset_orig(e, _interestRateModel,
            _daoFee, _deployerFee, _otherSilo);
        return interest;
    }
    if (siloContract == silo1)
    {
        wasAccrueInterestCalled_silo1 = true;
        uint256 interest = silo1._callAccrueInterestForAsset_orig(e, _interestRateModel,
            _daoFee, _deployerFee, _otherSilo);
        return interest;
    }
    assert false, "inccorrect silo";
    return 0;
}

