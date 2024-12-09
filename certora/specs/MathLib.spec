

methods {
    function getDebtAmountsWithInterest(uint256, uint256) 
        external returns (uint256, uint256) envfree;
        
}

// getDebtAmountsWithInterest() should never return values where 
// debtAssetsWithInterest + accruedInterest overflows
rule getDebtAmountsWithInterest_noOverflow(env e)
{
    uint256 _totalDebtAssets; uint256 _rcomp;

    uint256 debtAssetsWithInterest; uint256 accruedInterest;
    debtAssetsWithInterest, accruedInterest = getDebtAmountsWithInterest(_totalDebtAssets, _rcomp);
    uint res = assert_uint256(debtAssetsWithInterest + accruedInterest);
    assert true;
}

// getDebtAmountsWithInterest() should never return lower value for 
// debtAssetsWithInterest than _totalDebtAssets input
rule getDebtAmountsWithInterest_correctness(env e)
{
    uint256 _totalDebtAssets; uint256 _rcomp;

    uint256 debtAssetsWithInterest; uint256 accruedInterest;
    debtAssetsWithInterest, accruedInterest = getDebtAmountsWithInterest(_totalDebtAssets, _rcomp);
    assert debtAssetsWithInterest >= _totalDebtAssets;
}