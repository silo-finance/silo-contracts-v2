// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IOracleForwarder} from "silo-oracles/contracts/interfaces/IOracleForwarder.sol";

import {console2} from "forge-std/console2.sol";

contract OracleForwarder is Ownable2Step, IOracleForwarder {
    address public immutable INITIAL_QUOTE_TOKEN;

    ISiloOracle public oracle;

    constructor(ISiloOracle _oracle, address _owner) Ownable(_owner) {
        INITIAL_QUOTE_TOKEN = _oracle.quoteToken();

        _setOracle(_oracle);
    }

    /// @inheritdoc IOracleForwarder
    function setOracle(ISiloOracle _oracle) external onlyOwner {
        require(_oracle.quoteToken() == INITIAL_QUOTE_TOKEN, QuoteTokenMustBeTheSame());

        _setOracle(_oracle);
    }

    function beforeQuote(address _baseToken) external {
        oracle.beforeQuote(_baseToken);
    }

    function quote(uint256 _baseAmount, address _baseToken) external view returns (uint256 quoteAmount) {
        quoteAmount = oracle.quote(_baseAmount, _baseToken);
    }

    function quoteToken() external view returns (address quoteToken) {
        quoteToken = oracle.quoteToken();
    }

    function _setOracle(ISiloOracle _oracle) internal {
        oracle = _oracle;

        emit OracleSet(_oracle);
    }
}
