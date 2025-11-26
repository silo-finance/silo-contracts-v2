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

    constructor(SiloConfigOverride memory _override) {
        _siloConfigOverride = _override;
    }

    function beforeCreateSilo(ISiloConfig.InitData memory, address)
        internal
        pure
        override
        returns (address)
    {
        return address(0);
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
