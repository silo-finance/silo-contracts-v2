// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;
pragma abicoder v2;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {KeyValueStorage as KV} from "silo-foundry-utils/key-value/KeyValueStorage.sol";
import {IUniswapV3Oracle} from "silo-oracles/contracts/interfaces/IUniswapV3Oracle.sol";
import {IUniswapV3Pool} from "uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

library UniswapV3OraclesConfigsParser {
    string constant public CONFIGS_FILE = "silo-oracles/deploy/uniswap-v3-oracle/_configs.json";

    function getConfig(
        string memory _network,
        string memory _name
    )
        internal
        returns (IUniswapV3Oracle.UniswapV3DeploymentConfig memory config)
    {
        string memory poolKey = KV.getString(CONFIGS_FILE, _name, "pool");
        string memory quoteTokenKey = KV.getString(CONFIGS_FILE, _name, "quoteToken");
        uint256 periodForAvgPrice = KV.getUint(CONFIGS_FILE, _name, "periodForAvgPrice");
        uint256 blockTime = KV.getUint(CONFIGS_FILE, _name, "blockTime");

        require(periodForAvgPrice <= type(uint32).max, "periodForAvgPrice should be uint32");
        require(blockTime <= type(uint8).max, "blockTime should be uint8");

        config = IUniswapV3Oracle.UniswapV3DeploymentConfig({
            pool: IUniswapV3Pool(AddrLib.getAddressSafe(_network, poolKey)),
            quoteToken: AddrLib.getAddressSafe(_network, quoteTokenKey),
            periodForAvgPrice: uint32(periodForAvgPrice),
            blockTime: uint8(blockTime)
        });
    }
}
