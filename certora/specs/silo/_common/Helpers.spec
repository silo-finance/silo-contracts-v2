function disableAccrueInterest(env e) {
    require getSiloDataInterestRateTimestamp() == e.block.timestamp;
}

function isWithInterest(env e) returns bool {
    uint256 siloIRTimestamp = getSiloDataInterestRateTimestamp();
    require siloIRTimestamp <= e.block.timestamp;

    return siloIRTimestamp != 0 && siloIRTimestamp < e.block.timestamp;
}
