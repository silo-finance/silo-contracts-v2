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
    mathint siloBalance = token0.balanceOf(silo0);

    mathint balanceSum = collateralAssets + protectedAssets;

    require balanceSum < max_uint256;
    require siloBalance >= protectedAssets && siloBalance <= balanceSum;
}
