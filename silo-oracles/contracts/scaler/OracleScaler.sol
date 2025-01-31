// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";

/// @notice OracleScaler is an oracle, which scales the token amounts to 18 decimals instead of original decimals.
/// For example, USDC decimals are 6. 1 USDC is 10**6. This oracle will scale this amount to 10**18. If the token
/// decimals > 18, this oracle will revert.
/// This oracle was created to increase the precision for LTV calculation of low decimal tokens.
contract OracleScaler is ISiloOracle {
    /// @dev the amounts will be scaled to 18 decimals.
    uint8 public constant DECIMALS_TO_SCALE = 18;

    /// @dev base token address to use for a quote.
    address public immutable BASE_TOKEN; // solhint-disable-line var-name-mixedcase

    /// @dev scale factor will be multiplied with base token's amount to calculate the scaled value.
    uint256 public immutable SCALE_FACTOR; // solhint-disable-line var-name-mixedcase

    /// @dev revert if the original token decimals is more than 18
    error TokenDecimalsTooLarge();

    /// @dev revert if the baseToken to quote is not equal to BASE_TOKEN
    error TokenUnsupported();

    constructor(address _baseToken) {
        uint8 baseTokenDecimals = uint8(TokenHelper.assertAndGetDecimals(_baseToken));
        require(baseTokenDecimals <= DECIMALS_TO_SCALE, TokenDecimalsTooLarge());

        SCALE_FACTOR = 10 ** uint256(DECIMALS_TO_SCALE - baseTokenDecimals);

        BASE_TOKEN = _baseToken;
    }

    // @inheritdoc ISiloOracle
    function beforeQuote(address _baseToken) external virtual {}

    // @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external virtual view returns (uint256 quoteAmount) {
        if (_baseToken != BASE_TOKEN) {
            revert TokenUnsupported();
        }

        quoteAmount = _baseAmount * SCALE_FACTOR;
    }

    // @inheritdoc ISiloOracle
    function quoteToken() external virtual view returns (address) {
        return address(BASE_TOKEN);
    }
}
