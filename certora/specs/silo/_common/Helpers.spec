function disableAccrueInterest(env e) {
    require getSiloDataInterestRateTimestamp() == e.block.timestamp;
}

function isWithInterest(env e) returns bool {
    uint256 siloIRTimestamp = getSiloDataInterestRateTimestamp();
    require siloIRTimestamp <= e.block.timestamp;

    uint256 debt = silo0._total[ISilo.AssetType.Debt].assets;

    return siloIRTimestamp != 0 && siloIRTimestamp < e.block.timestamp && debt != 0;
}
