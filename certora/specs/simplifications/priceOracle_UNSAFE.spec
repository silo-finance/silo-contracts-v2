/* Setup which simplifies the price oracle `ISiloOracle` */
methods {
    // ---- `ISiloOracle` ------------------------------------------------------
    function _.quote(
        uint256 _baseAmount,
        address _baseToken
    ) external with (env e) => calculateTokenValue(
        calledContract,
        _baseToken,
        _baseAmount,
        e.block.timestamp
    ) expect uint256;

    // NOTE: Since `beforeQuote` is not a view function, strictly speaking this is unsound.
    function _.beforeQuote(address) external => NONDET;
}


definition VALUE1() returns uint256 = 1;  /// price is 0.5
definition VALUE2() returns uint256 = 2;  /// price is 1
definition VALUE3() returns uint256 = 6;  /// price is 3
definition PRECISION() returns uint256 = 2;


/// @title Generic price oracle
/// @notice The returned value will be
///     `(VALUEi * baseAmount + 1) / PRECISION`
function calculateTokenValue(
    address oracle,
    address token,
    uint256 baseAmount,
    uint256 time
) returns uint256 {
    return require_uint256(
        (priceOracle(oracle, token, time) * baseAmount + 1) / PRECISION()
    );
}

/// @title Ghost that determines the price oracle base value
/// @notice The returned value is one of `VALUE1`, `VALUE2` or `VALUE3`.
/// @notice This is a *persistent* ghost - not affected by havocs.
persistent ghost priceOracle(address, address, uint256) returns uint256 {
    axiom 
        forall address oracle.
            forall address token.
                forall uint256 timestamp. (
                    priceOracle(oracle, token, timestamp) == VALUE1() ||
                    priceOracle(oracle, token, timestamp) == VALUE2() ||
                    priceOracle(oracle, token, timestamp) == VALUE3()
                );
}
