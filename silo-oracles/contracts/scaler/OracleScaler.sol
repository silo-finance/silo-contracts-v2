// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

/// @notice OracleScaler is an oracle, which scales the token amounts to 18 decimals instead of original decimals.
/// For example, USDC decimals are 6. 1 USDC is 10**6. This oracle will scale this amount to 10**18. If the token
/// decimals >= 18, this oracle will revert.
/// This oracle was created to increase the precision for LTV calculation of low decimal tokens.
contract OracleScaler is ISiloOracle {
    /// @dev the amounts will be scaled to 18 decimals.
    uint8 public constant QUOTE_DECIMALS = 18;

    /// @dev quote token address to represent scaled amounts.
    IERC20Metadata public immutable QUOTE_TOKEN; // solhint-disable-line var-name-mixedcase

    /// @dev revert if the quote token decimals is not 18
    error InvalidQuoteTokenDecimals();
    
    /// @dev revert if the original token decimals is 18 or more
    error TokenDecimalsTooLarge();

    constructor(IERC20Metadata _quoteToken) {
        if (_quoteToken.decimals() != QUOTE_DECIMALS) {
            revert InvalidQuoteTokenDecimals();
        }

        QUOTE_TOKEN = _quoteToken;
    }

    // @inheritdoc ISiloOracle
    function beforeQuote(address _baseToken) external virtual {}

    // @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external virtual view returns (uint256 quoteAmount) {
        uint8 decimals = IERC20Metadata(_baseToken).decimals();

        if (decimals >= QUOTE_DECIMALS) {
            revert TokenDecimalsTooLarge();
        }

        quoteAmount = _baseAmount * (10**uint256(QUOTE_DECIMALS - decimals));
    }

    // @inheritdoc ISiloOracle
    function quoteToken() external virtual view returns (address) {
        return address(QUOTE_TOKEN);
    }
}
