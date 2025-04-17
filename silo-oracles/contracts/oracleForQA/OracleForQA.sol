// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

contract OracleForQA is ISiloOracle {
    address immutable QUOTE_TOKEN;
    uint256 immutable BASE_DECIMALS;

    uint256 public priceOfOneBaseToken;

    constructor (address base, address _quote) {
        QUOTE_TOKEN = _quote;
        BASE_DECIMALS = IERC20Metadata(base).decimals();
    }

    function quoteToken() external view override virtual returns (address) {
        return QUOTE_TOKEN;
    }

    /// @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external view virtual returns (uint256 quoteAmount) {
        return _baseToken == QUOTE_TOKEN
            ? _baseAmount
            : _baseAmount * priceOfOneBaseToken / (10 ** BASE_DECIMALS);
    }

    /// @param _price if oracle is set for WETH/USDC, where USDC is quote, then correct price would be 3000e6
    function setPriceOfOneBaseToken(uint256 _price) external {
        priceOfOneBaseToken = _price;
    }

    function beforeQuote(address) external pure virtual override {
        // nothing to execute
    }
}
