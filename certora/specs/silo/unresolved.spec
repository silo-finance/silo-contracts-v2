// let's add dispatchers here if we see unreaolsved calls
// we can later put it somehwere else

import "../requirements/two_silos_methods.spec";

methods {
    function _.reentrancyGuardEntered() external => DISPATCHER(true);
    function _.synchronizeHooks(uint24,uint24) external => NONDET;
    function _.getCollateralAndDebtTotalsStorage() external => DISPATCHER(true);
    function _.onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes  _data) external => NONDET;

    // ---- `IInterestRateModel` -----------------------------------------------
    
    // using _simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec instead
    // Since `getCompoundInterestRateAndUpdate` is not view, this is not strictly sound.
    // function _.getCompoundInterestRateAndUpdate(
    //     uint256 _collateralAssets,
    //     uint256 _debtAssets,
    //     uint256 _interestRateTimestamp
    // ) external => NONDET;

    // ---- `ISiloOracle` ------------------------------------------------------
    // NOTE: Since `beforeQuote` is not a view function, strictly speaking this is unsound.
    function _.beforeQuote(address) external => NONDET DELETE;
}


// IERC3156FlashBorrower for flashLoan .onFlashLoan
// violations to investigate:
    // debt_thenBorrowerCollateralSiloSetAndHasShares 
    // borrowerCollateralSilo_setNonzeroIncreasesBalance
    // borrowerCollateralSilo_setNonzeroIncreasesDebt

// storage equivalence violated for no obvious reas// ˙˙˙on accrueInterestForSilo_equivalent 
// how to invetigate sanity issues?
    // https://prover.certora.com/output/1000000000/0e85a451305b4c7394b2314d33792cde?anonymousKey=a0875810941731ae3c62f30248f062bf331a988a

