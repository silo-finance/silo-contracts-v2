// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Initializable} from  "openzeppelin5-upgradeable/proxy/utils/Initializable.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {IWrappedVaultOracle} from "../interfaces/IWrappedVaultOracle.sol";
import {WrappedVaultOracleConfig} from "./WrappedVaultOracleConfig.sol";

contract WrappedVaultOracle is IWrappedVaultOracle, ISiloOracle, Initializable {
    WrappedVaultOracleConfig public oracleConfig;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice validation of oracleConfig is checked in factory, therefore you should not deploy and initialize directly
    /// use factory always.
    function initialize(WrappedVaultOracleConfig _configAddress) external virtual initializer {
        oracleConfig = _configAddress;
        emit WrappedVaultOracleDeployed(_configAddress);
    }
    
    /// @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external view virtual returns (uint256 quoteAmount) {
        if (_baseAmount > type(uint128).max) revert BaseAmountOverflow();

        Config memory cfg = oracleConfig.getConfig();
        if (_baseToken != address(cfg.vault)) revert AssetNotSupported();

        uint256 underlyingAssets = cfg.vault.convertToAssets(_baseAmount);
        quoteAmount = cfg.oracle.quote(underlyingAssets, cfg.vaultAsset);
  
        if (quoteAmount == 0) revert ZeroQuote();
    }

    /// @inheritdoc ISiloOracle
    function quoteToken() external view virtual returns (address) {
        Config memory cfg = oracleConfig.getConfig();
        return cfg.quoteToken;
    }

    function beforeQuote(address) external pure virtual override {
        // nothing to execute
    }
}
