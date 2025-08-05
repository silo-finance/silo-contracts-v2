// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

contract ERC4626OracleHardcodeQuote is ISiloOracle {
    IERC4626 public immutable VAULT;
    address internal immutable _QUOTE_TOKEN;

    error AssetNotSupported();
    error ZeroPrice();

    constructor(IERC4626 _vault, address _quoteToken) {
        VAULT = _vault;
        _QUOTE_TOKEN = _quoteToken;
    }

    /// @inheritdoc ISiloOracle
    function beforeQuote(address _baseToken) external view virtual {
        // only for an ISiloOracle interface implementation
    }

    /// @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external view virtual returns (uint256 quoteAmount) {
        if (_baseToken != address(VAULT)) revert AssetNotSupported();

        quoteAmount = VAULT.convertToAssets(_baseAmount);

        if (quoteAmount == 0) revert ZeroPrice();
    }

    /// @inheritdoc ISiloOracle
    function quoteToken() external view virtual returns (address) {
        return _QUOTE_TOKEN;
    }
}
