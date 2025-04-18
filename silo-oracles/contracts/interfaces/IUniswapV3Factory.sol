// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IUniswapV3Oracle} from "./IUniswapV3Oracle.sol";

interface IUniswapV3Factory {
    function create(
        IUniswapV3Oracle.UniswapV3DeploymentConfig memory _config,
        bytes32 _externalSalt
    ) external returns (address oracle);
}
