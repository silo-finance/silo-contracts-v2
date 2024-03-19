methods {
    // Summarizations:
    function SolvencyLib.isSolvent(
        ISiloConfig.ConfigData memory collateralConfig,
        ISiloConfig.ConfigData memory debtConfig,
        address borrower,
        ISilo.AccrueInterestInMemory accrueInMemory,
        uint256 debtShareBalance
    ) internal returns (bool) => simplified_solvent(borrower, debtShareBalance);
}

ghost simplified_solvent(address, uint256) returns bool;
