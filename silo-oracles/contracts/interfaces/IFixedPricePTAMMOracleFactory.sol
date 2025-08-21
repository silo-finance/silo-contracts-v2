// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IFixedPricePTAMMOracleConfig} from "./IFixedPricePTAMMOracleConfig.sol";
import {IFixedPricePTAMMOracle} from "./IFixedPricePTAMMOracle.sol";

interface IFixedPricePTAMMOracleFactory {
    error DeployerCannotBeZero();
    error AddressZero();
    error TokensAreTheSame();

    function create(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config, bytes32 _externalSalt)
        external
        returns (IFixedPricePTAMMOracle oracle);
}
