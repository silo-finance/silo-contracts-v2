// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";
import {ManageableOracleFactory} from "silo-oracles/contracts/manageable/ManageableOracleFactory.sol";
import {IManageableOracle} from "silo-oracles/contracts/interfaces/IManageableOracle.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

/*
FOUNDRY_PROFILE=oracles UNDERLYING_ORACLE=SCALER_woS BASE_TOKEN=wBTC OWNER=0x... \
    forge script silo-oracles/deploy/manageable-oracle/ManageableOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify

Optional env: TIMELOCK (seconds, default 1 days), EXTERNAL_SALT (bytes32 hex, default 0).
OWNER defaults to deployer (address from PRIVATE_KEY) if not set.
 */
error UnderlyingOracleNotFound();

contract ManageableOracleDeploy is CommonDeploy {
    string public underlyingOracleKey;
    string public baseTokenKey;
    address public baseToken;
    address public owner;
    uint32 public timelock;
    bytes32 public externalSalt;

    function setUnderlyingOracleKey(string memory _key) public {
        underlyingOracleKey = _key;
    }

    function setBaseTokenKey(string memory _key) public {
        baseTokenKey = _key;
    }

    function setBaseToken(address _baseToken) public {
        baseToken = _baseToken;
    }

    function setOwner(address _owner) public {
        owner = _owner;
    }

    function setTimelock(uint32 _timelock) public {
        timelock = _timelock;
    }

    function setExternalSalt(bytes32 _externalSalt) public {
        externalSalt = _externalSalt;
    }

    function run() public returns (IManageableOracle manageableOracle) {
        AddrLib.init();

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployer = vm.addr(deployerPrivateKey);

        if (bytes(underlyingOracleKey).length == 0) {
            underlyingOracleKey = vm.envString("UNDERLYING_ORACLE");
        }
        if (bytes(baseTokenKey).length == 0) {
            baseTokenKey = vm.envString("BASE_TOKEN");
        }
        if (baseToken == address(0)) {
            baseToken = AddrLib.getAddress(baseTokenKey);
        }
        if (owner == address(0)) {
            owner = vm.envOr("OWNER", deployer);
        }
        if (timelock == 0) {
            timelock = uint32(vm.envOr("TIMELOCK", uint256(1 days)));
        }
        // externalSalt stays 0 unless set via setExternalSalt or EXTERNAL_SALT env
        if (vm.envOr("EXTERNAL_SALT", bytes32(0)) != bytes32(0)) {
            externalSalt = vm.envBytes32("EXTERNAL_SALT");
        }

        address underlyingOracle = OraclesDeployments.get(getChainAlias(), underlyingOracleKey);
        if (underlyingOracle == address(0)) revert UnderlyingOracleNotFound();

        address factoryAddress = getDeployedAddress(SiloOraclesFactoriesContracts.MANAGEABLE_ORACLE_FACTORY);
        ManageableOracleFactory factory = ManageableOracleFactory(factoryAddress);

        vm.startBroadcast(deployerPrivateKey);

        manageableOracle =
            factory.create(ISiloOracle(underlyingOracle), owner, timelock, baseToken, externalSalt);

        vm.stopBroadcast();

        string memory baseLabel = bytes(baseTokenKey).length != 0 ? baseTokenKey : vm.toString(baseToken);
        string memory oracleName = string.concat("MANAGEABLE_", underlyingOracleKey, "_", baseLabel);
        OraclesDeployments.save(getChainAlias(), oracleName, address(manageableOracle));
    }
}
