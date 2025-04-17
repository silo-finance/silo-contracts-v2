// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";

contract Data {
    mapping(string identifier => ISiloConfig.InitData siloInitData) internal siloData;
    mapping(string tokenName => address tokenAdddress) internal _tokens;
    mapping(string oracleName => address oracleAddress) internal oracles;
    mapping(string IRMConfigName => address IRMConfigAddress) internal IRMConfigs;
    mapping(string hookReceiverName => address hookReceiverAddress) internal hookReceivers;

    IInterestRateModelV2.Config[] presetIRMConfigs;

    constructor() {
        // set tokens
        _tokens["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Ethereum WETH
        _tokens["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Ethereum USDC

        // set preset IRM configs
        presetIRMConfigs.push(
            IInterestRateModelV2.Config({
                uopt: 500000000000000000,
                ucrit: 900000000000000000,
                ulow: 300000000000000000,
                ki: 146805,
                kcrit: 317097919838,
                klow: 105699306613,
                klin: 4439370878,
                beta: 69444444444444,
                ri: 0,
                Tcrit: 0
            })
        );
    }
}
