// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {StdCheatsSafe} from "forge-std/StdCheats.sol";

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

contract SiloOracleMockReturnSame is StdCheatsSafe, ISiloOracle {
    address public tokenAsQuote = makeAddr("SiloOracleMock.quoteToken");

    function beforeQuote(address) external {}

    function quote(uint256 _baseAmount, address) external pure returns (uint256 quoteAmount) {
        quoteAmount = _baseAmount;
    }

    function quoteToken() external view returns (address) {
        return tokenAsQuote;
    }
}
