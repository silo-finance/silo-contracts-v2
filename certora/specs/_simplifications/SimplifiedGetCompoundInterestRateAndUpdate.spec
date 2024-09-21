/* Setup which simplifies the interest rate model `IInterestRateModel` */
methods {
    // ---- `IInterestRateModel` -----------------------------------------------
    function _.getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    ) external with(env e) => compoundInterestRate(
        require_uint256(e.block.timestamp - _interestRateTimestamp)
    ) expect uint256;

    function _.getCompoundInterestRate(
        address _silo,
        uint256 _blockTimestamp
    ) external => getCompoundInterestRateSumm(_silo, _blockTimestamp) expect uint256;
}


definition RCOMP_MAX() returns uint256 = 2^16 * 10^18;  // Maximal compound interest


/// @title Ghost function deteermining the interest rate based on the time diff
ghost compoundInterestRate(uint256) returns uint256 {
    // `compoundInterestRate` is monotonic non-decreasing
    axiom forall uint256 timestampDiff0. forall uint256 timestampDiff1. (
        timestampDiff1 >= timestampDiff0 => 
        compoundInterestRate(timestampDiff1) >= compoundInterestRate(timestampDiff0)
    );

    axiom forall uint256 timestampDiff. compoundInterestRate(timestampDiff) <= RCOMP_MAX();
    axiom compoundInterestRate(0) == 0;
}


/// @title Implementation of `getCompoundInterestRate` in CVL
/// @notice This function would not revert, even if the given `_blockTimestamp` is less
/// than the interest rate time stamp!
function getCompoundInterestRateSumm(address _silo, uint256 _blockTimestamp) returns uint256 {
    uint256 interestRateTimestamp;
    if(_silo == silo0) {
        interestRateTimestamp = silo0.getSiloDataInterestRateTimestamp();
    } else if(_silo == silo1) {
        interestRateTimestamp = silo1.getSiloDataInterestRateTimestamp();
    } else {
        interestRateTimestamp = _;
        assert false, "Expected _silo to be either silo0 or silo1";
    }
    mathint timestampDiff = _blockTimestamp - interestRateTimestamp;
    return compoundInterestRate(require_uint256(timestampDiff));
}
