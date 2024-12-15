
# debt in both silos:
# certoraRun.py certora/config/silo/noDebtInBoth.conf --parametric_contracts Silo0 --msg "debtInBoth - Silo0"
certoraRun.py certora/config/silo/noDebtInBoth.conf --parametric_contracts ShareDebtToken0 ShareProtectedCollateralToken0 Token0 --msg "debtInBoth - tokens"

# certoraRun.py certora/config/silo/noDebtInBoth.conf --parametric_contracts Silo0 --msg "mut24 debtInBoth - Silo0"
# certoraRun.py certora/config/silo/noDebtInBoth.conf --parametric_contracts ShareDebtToken0 ShareProtectedCollateralToken0 Token0 --msg "mut24 debtInBoth - tokens"