// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {StdCheatsSafe} from "forge-std/StdCheats.sol";

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

contract SiloOracleMock2 is StdCheatsSafe, ISiloOracle {
    uint256 public constant QUOTE_AMOUNT = 2000000000000000000;
    address public tokenAsQuote = makeAddr("SiloOracleMock.quoteToken");

    event BeforeQuoteSiloOracleMock2();

    function beforeQuote(address _baseToken) external {
        emit BeforeQuoteSiloOracleMock2();
    }

    function quote(uint256 _baseAmount, address _baseToken) external view returns (uint256 quoteAmount) {
        quoteAmount = QUOTE_AMOUNT;
    }

    function quoteToken() external view returns (address) {
        return tokenAsQuote;
    }
}
