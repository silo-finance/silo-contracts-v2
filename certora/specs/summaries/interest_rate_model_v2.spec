/* Summaries for the Interest Rate Module V2 */

methods {
    
    // `envfree`
    function getSiloStorage() external returns (uint192,uint64,uint256,uint256,uint256) envfree ;
    
    // Dispatcher
    function _.getCollateralAndDebtTotalsStorage() external => DISPATCHER(true);
    function _.isSolvent(address) external => NONDET; // user solvency doesn't matter for these 
    function _.quote(address) external => NONDET;

    // ---- `IInterestRateModel` -----------------------------------------------
    // Since `getCompoundInterestRateAndUpdate` is not *pure*, this is not strictly sound
    // Be sure this is not a problem!
    // `ri` and `Tcrit` in storage typically change with this
    function _.getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    ) external =>  CVLGetCompoundInterestRateAndUpdate(
        _collateralAssets,
        _debtAssets,
        _interestRateTimestamp
    ) expect (uint256);
    
    // TODO: Soundness needs to be proved
    function _.getCompoundInterestRate(
        address _silo,
        uint256 _blockTimestamp
    ) external => CVLGetCompoundInterestRate(_silo, _blockTimestamp) expect (uint256);

    // ---- `ISiloOracle` ------------------------------------------------------
    // NOTE: Since `beforeQuote` is not a view function, strictly speaking this is unsound.
    function _.beforeQuote(address) external => NONDET DELETE;
}

// ---- Functions and ghosts ---------------------------------------------------

ghost mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256))) interestRateGhost;

// An arbitrary (pure) function for the interest rate
function CVLGetCompoundInterestRateAndUpdate(
    uint256 _collateralAssets,
    uint256 _debtAssets,
    uint256 _interestRateTimestamp
) returns uint256 {
    return interestRateGhost[_collateralAssets][_debtAssets][_interestRateTimestamp];
}


// A second arbitrary (pure) function for the interest rate 
function CVLGetCompoundInterestRate(
    address _silo,
    uint256 _blockTimestamp
) returns uint256 {    
    uint64  _interestRateTimestamp ;
    uint256 _collateralAssets ;
    uint256 _debtAssets ;
    (_,_interestRateTimestamp,_,_collateralAssets,_debtAssets) = getSiloStorage();
    
    // TODO verify that these two conditions hold, or summarize weaker versions of them
    if (_interestRateTimestamp == 0) {
        return 0;
    }

    if (_interestRateTimestamp == _blockTimestamp) {
        return 0;
    }

    return interestRateGhost[_collateralAssets][_debtAssets][_interestRateTimestamp];
}