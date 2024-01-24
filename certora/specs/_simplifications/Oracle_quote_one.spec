methods {
    function _.beforeQuote(address _baseToken) external => NONDET;
    function _.quote(uint256 _baseAmount, address _baseToken) external returns (uint256) => simplified_quote(_baseAmount, _baseToken);
}

function  simplified_quote(uint256 _baseAmount, address _baseToken) returns uint256 {
    return _baseAmount;
}
