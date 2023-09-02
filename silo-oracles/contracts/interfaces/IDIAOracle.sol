// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IDIAOracleV2} from "../external/dia/IDIAOracleV2.sol";
import {DIAOracleConfig} from "../dia/DIAOracleConfig.sol";

interface IDIAOracle {
    /// @param diaOracle IDIAOracleV2 Oracle deployed for by DIA, DIA prices will be submitted to this contract
    /// @param baseToken base token address
    /// @param quoteToken native token address, that we will became quote token
    /// DIA is providing prices in /USD (fiat) but we need quote token address, solution is to pick some stablecoin
    /// that will represent USD. It can be also ETH token, then price will be denominated in ETH.
    /// quote token is verified in factory.
    /// Few stablecoins are acceptable (see factory). For ETH as quote, check `ETH_ADDRESS` in factory.
    /// @param heartbeat price must be updated at least once every 24h based on DIA protocol, otherwise something
    /// is wrong, you can provide custom time eg +10 minutes in case update wil be late
    struct DIAConfig {
        IDIAOracleV2 diaOracle;
        IERC20Metadata baseToken;
        IERC20Metadata quoteToken;
        uint32 heartbeat;
    }

    struct DIASetup {
        IDIAOracleV2 diaOracle;
        address baseToken;
        address quoteToken;
        uint32 heartbeat;
        uint256 normalizationDivider;
        uint256 normalizationMultiplier;
        bool quoteIsEth;
        string key;
    }

    event AssetSetup(address indexed asset, string key);
    event OracleInit(DIAOracleConfig configAddress);

    error InvalidKey();
    error InvalidKeyEth();
    error OldPrice();
    error OldPriceEth();
    error NotSupported();
    error AssetNotSupported();
    error Overflow();
    error NosSupportedQuoteToken();
    error BaseAmountOverflow();
    error InvalidStablecoinToke();
}
