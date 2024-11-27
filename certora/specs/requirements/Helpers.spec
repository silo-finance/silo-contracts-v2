function disableAccrueInterest(env e) {
    require getSiloDataInterestRateTimestamp() == e.block.timestamp;
}

function isWithInterest(env e) returns bool {
    uint256 siloIRTimestamp = getSiloDataInterestRateTimestamp();
    uint256 debt = silo0.total(require_uint256(ISilo.AssetType.Debt));

    return siloIRTimestamp != 0 && siloIRTimestamp < e.block.timestamp && debt != 0;
}

function requireCorrectSilo0Balance() {
    mathint collateralAssets = silo0.total(require_uint256(ISilo.AssetType.Collateral));
    mathint protectedAssets = silo0.total(require_uint256(ISilo.AssetType.Protected));
    mathint debtAssets = silo0.total(require_uint256(ISilo.AssetType.Debt));
    mathint daoAndDeployerFees = getSiloDataDaoAndDeployerFees();
    mathint siloBalance = token0.balanceOf(silo0);

    mathint liquidity = debtAssets > collateralAssets ? 0 : collateralAssets - debtAssets;

    mathint expectedBalance = liquidity + protectedAssets + daoAndDeployerFees;

    require expectedBalance < max_uint256;
    require siloBalance == expectedBalance;
}

function requireCorrectSilo1Balance() {
    mathint collateralAssets = silo1.total(require_uint256(ISilo.AssetType.Collateral));
    mathint protectedAssets = silo1.total(require_uint256(ISilo.AssetType.Protected));
    mathint debtAssets = silo1.total(require_uint256(ISilo.AssetType.Debt));
    mathint daoAndDeployerFees = getSiloDataDaoAndDeployerFees();
    mathint siloBalance = token1.balanceOf(silo1);

    mathint liquidity = debtAssets > collateralAssets ? 0 : collateralAssets - debtAssets;

    mathint expectedBalance = liquidity + protectedAssets + daoAndDeployerFees;

    require expectedBalance < max_uint256;
    require siloBalance == expectedBalance;
}

function toAssetsRoundUpLike(mathint shares, mathint totalAssets, mathint totalShares) returns mathint {
    if (totalShares == 0 || totalAssets == 0) {
        return 0;
    }

    mathint numerator = shares * totalAssets;

    if (numerator % totalShares != 0) {
        return numerator / totalShares + 1;
    }

    return numerator / totalShares;
}
