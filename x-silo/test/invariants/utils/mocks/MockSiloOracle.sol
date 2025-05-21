// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Interfaces
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

contract MockSiloOracle is ISiloOracle {
    uint256 internal price;
    address public quoteToken;
    uint256 public quoteTokenDecimals;
    address public baseToken;
    uint256 public baseTokenDecimals;

    bool _expectBeforeQuote;
    bool _oracleBroken;

    constructor(address _baseToken, uint256 _price, address _quoteToken, uint256 _quoteTokenDecimals) {
        price = _price;
        quoteToken = _quoteToken;
        quoteTokenDecimals = _quoteTokenDecimals;
        baseToken = _baseToken;
        baseTokenDecimals = IERC20Metadata(_baseToken).decimals();
    }

    function beforeQuote(address _baseToken) external view {
        if (_baseToken == quoteToken) revert("beforeQuote: wrong base token");
        if (_oracleBroken) revert("beforeQuote: oracle is broken");
        if (!_expectBeforeQuote) revert("beforeQuote: was not expected, but was called anyway");
    }

    function setExpectBeforeQuote(bool _expect) external {
        _expectBeforeQuote = _expect;
    }

    function quote(uint256 _baseAmount, address _baseToken) external view returns (uint256 quoteAmount) {
        if (_baseToken == quoteToken) revert("quote: wrong base token");
        if (_oracleBroken) revert("quote: oracle is broken");


        return (_baseAmount * price + 10 ** baseTokenDecimals - 1) / 10 ** baseTokenDecimals;
    }

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function breakOracle() external {
        _oracleBroken = true;
    }

    function fixOracle() external {
        _oracleBroken = false;
    }
}
