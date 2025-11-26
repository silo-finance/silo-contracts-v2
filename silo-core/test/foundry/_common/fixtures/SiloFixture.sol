// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";

import {StdCheats} from "forge-std/StdCheats.sol";
import {CommonBase} from "forge-std/Base.sol";

import {MainnetDeploy} from "silo-core/deploy/MainnetDeploy.s.sol";
import {SiloDeployWithDeployerOwner} from "silo-core/deploy/silo/SiloDeployWithDeployerOwner.s.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

struct SiloConfigOverride {
    address token0;
    address token1;
    address hookReceiver;
    address hookReceiverImplementation;
    address solvencyOracle0;
    address maxLtvOracle0;
    string configName;
}

contract SiloDeploy_Local is SiloDeployWithDeployerOwner {
    bytes32 public constant CLONE_IMPLEMENTATION_KEY = keccak256(bytes("CLONE_IMPLEMENTATION"));

    SiloConfigOverride internal _siloConfigOverride;

    error SiloFixtureHookReceiverImplNotFound(string hookReceiver);

    constructor(SiloConfigOverride memory _override) {
        _siloConfigOverride = _override;
    }

    function beforeCreateSilo(ISiloConfig.InitData memory _config, address _hookReceiverImplementation)
        internal
        view
        override
        returns (address hookImplementation)
    {
        // Override the default values if overrides are provided
        if (_siloConfigOverride.token0 != address(0)) {
            console2.log("[override] token0 %s -> %s", _config.token0, _siloConfigOverride.token0);
            _config.token0 = _siloConfigOverride.token0;
        }

        if (_siloConfigOverride.token1 != address(0)) {
            console2.log("[override] token1 %s -> %s", _config.token1, _siloConfigOverride.token1);
            _config.token1 = _siloConfigOverride.token1;
        }

        if (_siloConfigOverride.solvencyOracle0 != address(0)) {
            console2.log(
                "[override] solvencyOracle0 %s -> %s", _config.solvencyOracle0, _siloConfigOverride.solvencyOracle0
            );

            _config.solvencyOracle0 = _siloConfigOverride.solvencyOracle0;
        }

        if (_siloConfigOverride.maxLtvOracle0 != address(0)) {
            console2.log(
                "[override] maxLtvOracle0 %s -> %s", _config.maxLtvOracle0, _siloConfigOverride.maxLtvOracle0
            );

            _config.maxLtvOracle0 = _siloConfigOverride.maxLtvOracle0;
        }
    }
}

contract SiloFixture is StdCheats, CommonBase {
    bool internal _mainNetDeployed;

    function deploy_ETH_USDC()
        external
        returns (ISiloConfig, ISilo, ISilo, address, address, address)
    {
        // return _deploy(new SiloDeployWithDeployerOwner(), SiloConfigsNames.SILO_ETH_USDC_UNI_V3);
    }

    function deploy_local(string memory)
        external
        returns (
            ISiloConfig,
            ISilo,
            ISilo,
            address,
            address,
            address
        )
    {
        // SiloConfigOverride memory overrideArgs;
        // return _deploy(new SiloDeploy_Local(overrideArgs), _configName);
    }

    function deploy_local(SiloConfigOverride memory _override)
        external
        returns (
            ISiloConfig,
            ISilo,
            ISilo,
            address,
            address,
            address
        )
    {
        
            new SiloDeploy_Local(_override);
            // bytes(_override.configName).length == 0
            //     ? SiloConfigsNames.SILO_LOCAL_NO_ORACLE_SILO
            //     : _override.configName
        
    }
}
