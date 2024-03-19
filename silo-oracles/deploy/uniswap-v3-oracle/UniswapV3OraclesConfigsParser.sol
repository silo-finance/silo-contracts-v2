// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;
pragma abicoder v2;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {KeyValueStorage as KV} from "silo-foundry-utils/key-value/KeyValueStorage.sol";
import {IUniswapV3Oracle} from "silo-oracles/contracts/interfaces/IUniswapV3Oracle.sol";
import {IUniswapV3Pool} from "uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

library UniswapV3OraclesConfigsParser {
    string constant public CONFIGS_DIR = "silo-oracles/deploy/uniswap-v3-oracle/configs/";
    string constant internal _EXTENSION = ".json";

    function getConfig(
        string memory _network,
        string memory _name
    )
        internal
        returns (IUniswapV3Oracle.UniswapV3DeploymentConfig memory config)
    {
        string memory configJson = configFile();

        string memory poolKey = KV.getString(configJson, _name, "pool");
        string memory baseTokenKey = KV.getString(configJson, _name, "baseToken");
        string memory quoteTokenKey = KV.getString(configJson, _name, "quoteToken");
        uint256 periodForAvgPrice = KV.getUint(configJson, _name, "periodForAvgPrice");
        uint256 blockTime = KV.getUint(configJson, _name, "blockTime");

        require(periodForAvgPrice <= type(uint32).max, "periodForAvgPrice should be uint32");
        require(blockTime <= type(uint8).max, "blockTime should be uint8");

        config = IUniswapV3Oracle.UniswapV3DeploymentConfig({
            pool: IUniswapV3Pool(AddrLib.getAddressSafe(_network, poolKey)),
            baseToken: AddrLib.getAddressSafe(_network, baseTokenKey),
            quoteToken: AddrLib.getAddressSafe(_network, quoteTokenKey),
            periodForAvgPrice: uint32(periodForAvgPrice),
            blockTime: uint8(blockTime)
        });
    }

    function configFile() internal view returns (string memory file) {
        file = string(abi.encodePacked(CONFIGS_DIR, ChainsLib.chainAlias(), _EXTENSION));
    }
}
