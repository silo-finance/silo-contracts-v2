// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

contract OracleForQA is ISiloOracle {
    address immutable QUOTE_TOKEN;
    uint256 immutable ONE_TOKEN;

    uint256 public price;

    constructor (address _quote) {
        QUOTE_TOKEN = _quote;
        ONE_TOKEN = 10 ** IERC20Metadata(_quote).decimals();
    }

    function quoteToken() external view override virtual returns (address) {
        return QUOTE_TOKEN;
    }

    /// @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external view virtual returns (uint256 quoteAmount) {
        return _baseToken == QUOTE_TOKEN ? _baseAmount : _baseAmount * price / ONE_TOKEN;
    }

    function setPriceForOneToken(uint256 _price) external {
       price = _price;
    }

    function beforeQuote(address) external pure virtual override {
        // nothing to execute
    }
}
