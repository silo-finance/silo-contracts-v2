methods {
    function _.quote(uint256 _baseAmount, address _baseToken) external with (env e)
        => priceOracle(calledContract, _baseToken, _baseAmount, e.block.timestamp) expect uint256;
}
/*
Generic price oracle : 
    priceOracle(address oracle, address base token, uint256 amount, uint256 timestamp)
*/
persistent ghost priceOracle(address,address,uint256,uint256) returns uint256 {
    axiom 
        forall address oracle.
            forall address token.
                forall uint256 timestamp.
                    priceOracle(oracle, token, 0, timestamp) == 0;

    axiom 
        forall address oracle.
            forall address token.
                forall uint256 timestamp.
                    forall uint256 amount1. forall uint256 amount2. (
                        (amount1 < amount2 => 
                            priceOracle(oracle, token, amount1, timestamp) <= priceOracle(oracle, token, amount2, timestamp)
                        ) && (
                        amount1 * 2 == to_mathint(amount2) =>
                            2 * priceOracle(oracle, token, amount1, timestamp) == to_mathint(priceOracle(oracle, token, amount2, timestamp))
                        )
                    );         
}
