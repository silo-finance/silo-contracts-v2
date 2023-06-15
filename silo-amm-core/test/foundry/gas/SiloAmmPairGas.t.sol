// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../../contracts/SiloAmmPair.sol";
import "../helpers/Fixtures.sol";


/*
    FOUNDRY_PROFILE=amm forge test -vvv --match-contract Create2GasTest
*/
contract SiloAmmPairGasTest is Test, Fixtures {
    SiloAmmPair immutable pair;

    constructor() {
        address router = address(1);
        address silo = address(2);
        address token0 = address(3);
        address token1 = address(4);
        ISiloOracle oracle0;
        ISiloOracle oracle1;

        pair = new SiloAmmPair(router, silo, token0, token1, oracle0, oracle1, ammPriceConfig);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_SiloAmmPair_swap
    */
    function test_SiloAmmPair_swap() public {
        uint256 gasStart = gasleft();
        // pair.swap(1e18, 0, address(this), ""); TODO
        uint256 gasEnd = gasleft();

        uint256 gas = gasStart - gasEnd;
        emit log_named_uint("swap gas", gas);
    }
}
