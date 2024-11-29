// let's add dispatchers here if we see unreaolsved calls
// we can later put it somehwere else

import "../requirements/two_silos_methods.spec";

methods {
    function _.reentrancyGuardEntered() external => DISPATCHER(true);
    function _.synchronizeHooks(uint24,uint24) external => NONDET;

    // ---- `IInterestRateModel` -----------------------------------------------
    // Since `getCompoundInterestRateAndUpdate` is not view, this is not strictly sound.
    function _.getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    ) external => NONDET;

    // ---- `ISiloOracle` ------------------------------------------------------
    // NOTE: Since `beforeQuote` is not a view function, strictly speaking this is unsound.
    function _.beforeQuote(address) external => NONDET DELETE;
}

// mathlib summaries fixed
// more links in conf?
// callOnBehalf - ignore
// summary recursion limit..
//       https://prover.certora.com/output/6893/0a20bd795b224a37a5290b76596ba472/?anonymousKey=015c8e4b94d82f0818231421dc3f4800c5785153
//       debtInBoth
// do we need permit?

// unresolved.spec
// totalSupply
// submodules ?