function disableAccrueInterest(env e) {
    require getSiloDataInterestRateTimestamp() == e.block.timestamp;
}

function isWithInterest(env e) returns bool {
    uint256 siloIRTimestamp = getSiloDataInterestRateTimestamp();
    require siloIRTimestamp <= e.block.timestamp;

    uint256 debt = silo0.total(ISilo.AssetType.Debt);

    return siloIRTimestamp != 0 && siloIRTimestamp < e.block.timestamp && debt != 0;
}

function requireCorrectSiloBalance() {
    mathint collateralAssets = silo0.total(ISilo.AssetType.Collateral);
    mathint protectedAssets = silo0.total(ISilo.AssetType.Protected);
    mathint debtAssets = silo0.total(ISilo.AssetType.Debt);
    mathint daoAndDeployerFees = getSiloDataDaoAndDeployerFees();
    mathint siloBalance = token0.balanceOf(silo0);

    mathint liquidity = debtAssets > collateralAssets ? 0 : collateralAssets - debtAssets;

    mathint expectedBalance = liquidity + protectedAssets + daoAndDeployerFees;

    require expectedBalance < max_uint256;
    require siloBalance == expectedBalance;
}
