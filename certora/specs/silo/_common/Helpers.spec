function disableAccrueInterest(env e) {
    require getSiloDataInterestRateTimestamp() == e.block.timestamp;
}

// function requireAccrueInterest(env e) {
//     uint256 siloIRTimestamp = getSiloDataInterestRateTimestamp();
//     require siloIRTimestamp > 0 && assert_uint256(siloIRTimestamp + 30 * 86400) == e.block.timestamp;
// }

function requireRcompMax() {
    // RCOMP_MAX = (2**16) * 1e18;
    
}
