methods {
    function _.quote(uint256 _baseAmount, address _baseToken) external
        => price_is_one(_baseAmount, _baseToken) expect uint256;
}

function price_is_one(uint256 _baseAmount, address _baseToken) returns uint256 {
    return _baseAmount;
}
