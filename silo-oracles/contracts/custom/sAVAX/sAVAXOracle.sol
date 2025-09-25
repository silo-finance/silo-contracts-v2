// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IsAVAX} from "silo-oracles/contracts/interfaces/IsAVAX.sol";

contract sAVAXOracle is ISiloOracle {
    IsAVAX public constant S_AVAX = IsAVAX(0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE);

    error AssetNotSupported();
    error ZeroPrice();

    /// @inheritdoc ISiloOracle
    function beforeQuote(address _baseToken) external view {
        // only for an ISiloOracle interface implementation
    }

    /// @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external view returns (uint256 quoteAmount) {
        if (_baseToken != address(S_AVAX)) revert AssetNotSupported();

        quoteAmount = S_AVAX.getPooledAvaxByShares(_baseAmount);

        if (quoteAmount == 0) revert ZeroPrice();
    }

    /// @inheritdoc ISiloOracle
    function quoteToken() external view virtual returns (address) {
        return 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7; // WAVAX
    }
}
