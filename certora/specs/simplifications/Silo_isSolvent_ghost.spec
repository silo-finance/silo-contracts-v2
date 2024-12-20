methods {
    // Summarizations:
    function SiloSolvencyLib.isSolvent(
        ISiloConfig.ConfigData memory collateralConfig,
        ISiloConfig.ConfigData memory debtConfig,
        ISiloConfig.DebtInfo memory debtInfo,
        address borrower,
        ISilo.AccrueInterestInMemory accrueInMemory
    ) internal returns (bool) => simplified_solvent(borrower);
}

ghost simplified_solvent(address) returns bool;
