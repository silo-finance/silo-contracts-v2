// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";

import {IDynamicKinkModel} from "silo-core/contracts/interfaces/IDynamicKinkModel.sol";

import {DKinkIRMConfigDataReader} from "./DKinkIRMConfigDataReader.sol";
import {DKinkIRMImmutableDataReader} from "./DKinkIRMImmutableDataReader.sol";
import {StringLib} from "../lib/StringLib.sol";

contract DKinkIRMConfigData is DKinkIRMConfigDataReader, DKinkIRMImmutableDataReader {
    error ConfigNotFound();

    function getAllConfigs() public view returns (KinkJsonData[] memory, ImmutableArgs[] memory) {
        return (_getAllConfigs(), _getAllImmutableArgs());
    }

    /// @param _name The name of the KinkIRM config in format <config>:<immutable> eg: "zero:T0_C100"
    function getConfigData(string memory _name)
        public
        view
        returns (IDynamicKinkModel.Config memory cfg, IDynamicKinkModel.ImmutableArgs memory args)
    {
        (string memory configName, string memory immutableName) = _splitName(_name);

        KinkJsonData memory modelConfig = _getModelConfig(configName);
        ImmutableArgs memory immutableArgs = _getImmutableArgs(immutableName);

        cfg = _castToConfig(modelConfig);
        args = _castToImmutableArgs(immutableArgs);
    }

    function _splitName(string memory _name)
        private
        pure
        returns (string memory configName, string memory immutableName)
    {
        string[] memory parts = StringLib.split(_name, ":");

        require(
            parts.length == 2,
            string.concat("ERROR: expect 2 parts separated by `:` <config>:<immutable> got `", string(_name))
        );

        configName = parts[0];
        immutableName = parts[1];

        require(bytes(configName).length != 0, string.concat("ERROR: empty configName: `", string(_name)));

        require(bytes(immutableName).length != 0, string.concat("ERROR: empty immutableName: `", string(_name)));
    }

    function _castToConfig(KinkJsonData memory _modelConfig)
        private
        pure
        returns (IDynamicKinkModel.Config memory cfg)
    {
        cfg.ulow = _modelConfig.config.ulow;
        cfg.u1 = _modelConfig.config.u1;
        cfg.u2 = _modelConfig.config.u2;
        cfg.ucrit = _modelConfig.config.ucrit;
        cfg.rmin = _modelConfig.config.rmin;
        cfg.kmin = int96(int256(_modelConfig.config.kmin));
        cfg.kmax = int96(int256(_modelConfig.config.kmax));
        cfg.alpha = _modelConfig.config.alpha;
        cfg.cminus = _modelConfig.config.cminus;
        cfg.cplus = _modelConfig.config.cplus;
        cfg.c1 = _modelConfig.config.c1;
        cfg.c2 = _modelConfig.config.c2;
        cfg.dmax = _modelConfig.config.dmax;
    }

    function _castToImmutableArgs(ImmutableArgs memory _immutableArgs)
        private
        pure
        returns (IDynamicKinkModel.ImmutableArgs memory args)
    {
        args.timelock = _immutableArgs.args.timelock;
        args.rcompCap = _immutableArgs.args.rcompCap;
    }
}
