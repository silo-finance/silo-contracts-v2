// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IFixedPricePTAMMOracleConfig} from "./IFixedPricePTAMMOracleConfig.sol";

interface IFixedPricePTAMMOracle is ISiloOracle {
    event FixedPricePTAMMOracleInitialized(IFixedPricePTAMMOracleConfig indexed configAddress);

    error EmptyConfigAddress();
    error NotInitialized();
    error AssetNotSupported();
    error BaseAmountOverflow();
    error ZeroQuote();

    function initialize(IFixedPricePTAMMOracleConfig _configAddress) external;
}
