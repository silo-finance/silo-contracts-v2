// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";

import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";

import {IPTLinearOracleFactory} from "silo-oracles/contracts/interfaces/IPTLinearOracleFactory.sol";

import {
    SiloOraclesFactoriesContracts,
    SiloOraclesFactoriesDeployments
} from "silo-oracles/deploy/SiloOraclesFactoriesContracts.sol";

import {StringLib} from "./StringLib.sol";

library PTLinearOracleTxLib {
    bytes32 private constant PT_LINEAR_ORACLE_CONFIG_PREFIX_HASH = keccak256(bytes("PTLinearOracle"));

    function pendleLinearOracleTxData(string memory _oracleConfigName)
        internal
        returns (ISiloDeployer.OracleCreationTxData memory txData)
    {
        string memory chainAlias = ChainsLib.chainAlias();

        (bool success, address ptToken, uint256 discount, address quote) = decodeConfiguration(_oracleConfigName);
        require(success, string.concat(_oracleConfigName, " is invalid PTLinearOracle configuration"));

        txData.factory =
            SiloOraclesFactoriesDeployments.get(SiloOraclesFactoriesContracts.PT_LINEAR_ORACLE_FACTORY, chainAlias);

        IPTLinearOracleFactory.DeploymentConfig memory config = IPTLinearOracleFactory.DeploymentConfig({
            ptToken: ptToken,
            maxYield: discount,
            hardcodedQuoteToken: quote
        });

        // bytes32(0) is the salt for the create2 call and it will be overridden by the SiloDeployer
        txData.txInput = abi.encodeCall(IPTLinearOracleFactory.create, (config, bytes32(0)));
    }

    /// @param _oracleConfigName for pendle linear oracle we expect format: PTLinearOracle:<discount>:<quote>
    function isPendleLinearOracle(string memory _oracleConfigName) internal returns (bool isConfigForPendle) {
        (isConfigForPendle,,,) = decodeConfiguration(_oracleConfigName);
    }

    function decodeConfiguration(string memory _oracleConfigName)
        private
        returns (bool success, address ptToken, uint256 discount, address quote)
    {
        string[] memory parts = StringLib.split(_oracleConfigName, ":");
        require(parts.length == 4, string.concat("expect 4 parts separated with `:`, got: ", _oracleConfigName));

        success = keccak256(bytes(parts[0])) == PT_LINEAR_ORACLE_CONFIG_PREFIX_HASH;
        if (!success) return (false, address(0), 0, address(0));

        ptToken = SiloCoreDeployments.parseAddress(parts[1]);
        if (ptToken == address(0)) ptToken = AddrLib.getAddress(ChainsLib.chainAlias(), parts[1]);

        require(ptToken != address(0), string.concat("PTLinearOracle: unable to parse `", parts[1], "` to PT token."));

        require(
            bytes(parts[2]).length <= 5,
            string.concat("discount configuration must be in 4 decimals: `", parts[2], "`")
        );

        discount = StringLib.toUint256(parts[2]) * 1e14; // 1e18 == 100%

        require(
            discount > 0, string.concat(_oracleConfigName, ", discount configuration must be > 0%: `", parts[2], "`")
        );

        require(
            discount < 1e18,
            string.concat(_oracleConfigName, ", discount configuration must be less than 100%: `", parts[2], "`")
        );

        quote = SiloCoreDeployments.parseAddress(parts[3]);
        if (quote == address(0)) quote = AddrLib.getAddress(ChainsLib.chainAlias(), parts[3]);

        require(
            quote != address(0), string.concat("PTLinearOracle: unable to parse `", parts[3], "` to quote address.")
        );
    }
}
