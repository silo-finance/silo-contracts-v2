// let's add dispatchers here if we see unreaolsved calls
// we can later put it somehwere else

import "../requirements/two_silos_methods.spec";

methods {
    function _.reentrancyGuardEntered() external => DISPATCHER(true);
    function _.synchronizeHooks(uint24,uint24) external => NONDET;
    function _.getCollateralAndDebtTotalsStorage() external => DISPATCHER(true);
    function _.onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes  _data) external => NONDET;

    // ---- `IInterestRateModel` -----------------------------------------------
    
    // using simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec instead
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


// hard funcs according to --nondet_difficult_funcs:

// function SiloERC4626Lib.maxWithdrawWhenDebt(ISiloConfig.ConfigData,ISiloConfig.ConfigData,address,uint256,uint256,ISilo.CollateralType,uint256) internal returns (uint256,uint256) 
//     => NONDET /* difficulty 83 */; 
// function SiloLendingLib.calculateMaxBorrow(ISiloConfig.ConfigData,ISiloConfig.ConfigData,address,uint256,uint256,Contract ISiloConfig) internal returns (uint256,uint256) 
//     => NONDET /* difficulty 118 */; 
// function SiloSolvencyLib.getLtv(ISiloConfig.ConfigData,ISiloConfig.ConfigData,address,ISilo.OracleType,ISilo.AccrueInterestInMemory,uint256) internal returns (uint256) 
//     => NONDET /* difficulty 69 */; 
// function SiloSolvencyLib.isSolvent(ISiloConfig.ConfigData,ISiloConfig.ConfigData,address,ISilo.AccrueInterestInMemory) internal returns (bool) 
//     => NONDET /* difficulty 53 */; 
// function SiloLendingLib.maxBorrow(address,bool) internal returns (uint256,uint256) 
//     => NONDET /* difficulty 186 */; 
// function SiloERC4626Lib.maxWithdraw(address,ISilo.CollateralType,uint256) internal returns (uint256,uint256) 
//     => NONDET /* difficulty 141 */; 
// function SiloSolvencyLib.isBelowMaxLtv(ISiloConfig.ConfigData,ISiloConfig.ConfigData,address,ISilo.AccrueInterestInMemory) internal returns (bool) 
//     => NONDET /* difficulty 53 */;

// show that issolventafter is being called after every method, then summarise it to nondet
// summarise some of tha hard methods
// show that accrue is called at the beginning of every method

// debtInBoth:
// mutant 24: config 160, 364, 350 return false
// mutant 25: config 364, sharedebtToken 101
// mutant 26: actions 123, 156

// accrue:
// mutant 20 Actions 91: siloConfig.accrueInterestForBothSilos() => siloConfig.accrueInterestForSilo(address(this))

// mutant 21 ShareCollateralTokenLib: 28 siloConfig.accrueInterestForBothSilos() => siloConfig.accrueInterestForSilo(address($.silo));
//           sharedebtToken 130

// mutant 22 : partial liquidation

