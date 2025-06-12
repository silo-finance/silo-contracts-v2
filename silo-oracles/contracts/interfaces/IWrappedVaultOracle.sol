// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IWrappedVaultOracle {
    event WrappedVaultOracleDeployed(address configAddress);

    error BaseAmountOverflow();
    error AssetNotSupported();
    error ZeroQuote();
    error AssetZero();
    error QuoteTokenZero();
}
