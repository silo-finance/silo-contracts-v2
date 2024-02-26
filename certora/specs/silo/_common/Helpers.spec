function disableAccrueInterest(env e) {
    require currentContract.siloData.interestRateTimestamp == require_uint64(e.block.timestamp);
}

function isWithInterest(env e) returns bool {
    uint256 debt = currentContract._total[ISilo.AssetType.Debt].assets;

    uint256 siloIRTimestamp = getSiloDataInterestRateTimestamp(e);
    return siloIRTimestamp != 0 && siloIRTimestamp < e.block.timestamp && debt != 0;
}
