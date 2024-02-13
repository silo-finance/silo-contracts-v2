function disableAccrueInterest(env e) {
    require getSiloDataInterestRateTimestamp() == e.block.timestamp;
}

function isWithInterest(env e) returns bool {
    uint256 siloIRTimestamp = getSiloDataInterestRateTimestamp();
    require siloIRTimestamp <= e.block.timestamp;

    uint256 debt = silo0._total[ISilo.AssetType.Debt].assets;

    return siloIRTimestamp != 0 && siloIRTimestamp < e.block.timestamp && debt != 0;
}

function requireCorrectSiloBalance() {
    mathint collateralAssets = silo0._total[ISilo.AssetType.Collateral].assets;
    mathint protectedAssets = silo0._total[ISilo.AssetType.Protected].assets;
    mathint debtAssets = silo0._total[ISilo.AssetType.Debt].assets;
    mathint daoAndDeployerFees = getSiloDataDaoAndDeployerFees();
    mathint siloBalance = token0.balanceOf(silo0);

    require collateralAssets < max_uint256;
    require protectedAssets < max_uint256;
    require debtAssets < max_uint256;
    require siloBalance < max_uint256;
    require daoAndDeployerFees < max_uint256;

    mathint liquidity = debtAssets > collateralAssets ? 0 : collateralAssets - debtAssets;

    mathint expectedBalance = liquidity + protectedAssets + daoAndDeployerFees;

    require expectedBalance < max_uint256;
    require siloBalance == expectedBalance;
}
