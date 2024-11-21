/* The specification of the Interest Rate Module (v2) */
using Silo0 as silo0;

// ---- Methods block ----------------------------------------------------------
methods {
    // dispatchers
    function _.getSiloStorage() external => DISPATCHER(true) ;
    function _.utilizationData() external => DISPATCHER(true) ;

    // `envfree`
    function getCompoundInterestRate(address,uint256) external returns (uint256) envfree ;
   
}

// ---- Functions and ghosts ---------------------------------------------------

// Prevents having block timestamp less than interest rate timestamp
function silosTimestampSetupRequirements(env e) {
    require silo0.getSiloDataInterestRateTimestamp(e) <= require_uint64(e.block.timestamp) ;
}


// ---- Rules and Invariants ----------------------------------------------------

// status: Done https://prover.certora.com/output/39601/b1543c3777384d7d844f185e90aaa2af?anonymousKey=f213890145e36e068afc2d58f9bd05812f0851b5 
/// @title getCompoundInterestRate returns 0 if the interest rate timestamp is 0
rule interestRateTimestamp0() {
    env e;

    // block timestamp >= interest rate timestamp
    silosTimestampSetupRequirements(e);

    uint64 _interestRateTimestamp ;
    uint256 _blockTimestamp ;
    _interestRateTimestamp = silo0.getSiloDataInterestRateTimestamp(e);
    _blockTimestamp = e.block.timestamp ;

    // require that if the silo holds anything, interest rate timestamp > 0
    uint256 _collateralAssets ;
    uint256 _debtAssets ;
    _collateralAssets = silo0.getCollateralAssets(e) ;
    _debtAssets = silo0.getDebtAssets(e) ;
    require _collateralAssets > 0 || _debtAssets > 0 => _interestRateTimestamp > 0 ;

    assert (_interestRateTimestamp == 0 =>
            getCompoundInterestRate(silo0, _blockTimestamp) == 0) ;
}

// status: Done https://prover.certora.com/output/39601/7725bd8d3f324178ae3ca08b3e60346a?anonymousKey=49e7e9d4cbb3e051d736e5aec44b5c8c6b68f086
/// @title getCompoundInterestRate returns 0 if the block timestamp is 0
rule interestRateTimestampIsBlockTimestamp() {
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);

    uint64 _interestRateTimestamp ;
    uint256 _blockTimestamp ;
    _interestRateTimestamp = silo0.getSiloDataInterestRateTimestamp(e);
    _blockTimestamp = e.block.timestamp ;

    // _interestRateTimestamp == _blockTimestamp => returns 0
    assert (_interestRateTimestamp == require_uint64(_blockTimestamp) =>
            getCompoundInterestRate(silo0, _blockTimestamp) == 0) ;
}