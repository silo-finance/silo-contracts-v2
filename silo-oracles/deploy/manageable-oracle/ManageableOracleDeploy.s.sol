// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

// solhint-disable no-console
import {console2} from "forge-std/console2.sol";

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {PriceFormatter} from "silo-core/deploy/lib/PriceFormatter.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";
import {ManageableOracleFactory} from "silo-oracles/contracts/manageable/ManageableOracleFactory.sol";
import {IManageableOracle} from "silo-oracles/contracts/interfaces/IManageableOracle.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

/*
FOUNDRY_PROFILE=oracles UNDERLYING_ORACLE=SCALER_woS BASE_TOKEN=wBTC OWNER=DAO \
    forge script silo-oracles/deploy/manageable-oracle/ManageableOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify

Env BASE_TOKEN and OWNER are address names (e.g. USDC, DAO) resolved to addresses via AddrLib.
Optional env: TIMELOCK (seconds, default 1 days), EXTERNAL_SALT (bytes32 hex, default 0).
OWNER env defaults to deployer (address from PRIVATE_KEY) when not set.
 */
error UnderlyingOracleNotFound();

contract ManageableOracleDeploy is CommonDeploy {
    string public underlyingOracleKey;
    address public baseToken;
    address public owner;
    uint32 public timelock;
    bytes32 public externalSalt;

    function setUnderlyingOracleKey(string memory _key) public {
        underlyingOracleKey = _key;
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

        string memory underlyingKey = _getUnderlyingOracleKey();
        address underlyingOracle = OraclesDeployments.get(getChainAlias(), underlyingKey);
        if (underlyingOracle == address(0)) revert UnderlyingOracleNotFound();

        address baseTokenAddr = _getBaseToken();
        address ownerAddr = _getOwner(deployer);
        uint32 timelockVal = _getTimelock();
        bytes32 externalSaltVal = _getExternalSalt();

        address factoryAddress = getDeployedAddress(SiloOraclesFactoriesContracts.MANAGEABLE_ORACLE_FACTORY);
        ManageableOracleFactory factory = ManageableOracleFactory(factoryAddress);

        vm.startBroadcast(deployerPrivateKey);

        manageableOracle =
            factory.create(ISiloOracle(underlyingOracle), ownerAddr, timelockVal, baseTokenAddr, externalSaltVal);

        vm.stopBroadcast();

        string memory oracleName = _getOracleName(address(manageableOracle), baseTokenAddr);
        OraclesDeployments.save(getChainAlias(), oracleName, address(manageableOracle));

        _qa(address(manageableOracle), baseTokenAddr);
    }

    function _getUnderlyingOracleKey() internal view returns (string memory) {
        if (bytes(underlyingOracleKey).length != 0) return underlyingOracleKey;
        return vm.envString("UNDERLYING_ORACLE");
    }

    function _getBaseToken() internal returns (address) {
        if (baseToken != address(0)) return baseToken;
        return AddrLib.getAddress(vm.envString("BASE_TOKEN"));
    }

    function _getOwner(address _deployer) internal returns (address) {
        if (owner != address(0)) return owner;
        string memory ownerName = vm.envString("OWNER");
        if (bytes(ownerName).length == 0) return _deployer;
        return AddrLib.getAddress(ownerName);
    }

    function _getTimelock() internal view returns (uint32) {
        if (timelock != 0) return timelock;
        return uint32(vm.envUint("TIMELOCK"));
    }

    function _getExternalSalt() internal view returns (bytes32) {
        if (externalSalt != bytes32(0)) return externalSalt;
        if (vm.envOr("EXTERNAL_SALT", bytes32(0)) != bytes32(0)) return vm.envBytes32("EXTERNAL_SALT");
        return bytes32(0);
    }

    function _getOracleName(address _oracle, address _baseToken) internal view returns (string memory) {
        address quoteToken = ISiloOracle(_oracle).quoteToken();
        string memory baseSymbol = IERC20Metadata(_baseToken).symbol();
        string memory quoteSymbol = IERC20Metadata(quoteToken).symbol();
        return string.concat("MANAGEABLE_ORACLE_", baseSymbol, "_", quoteSymbol);
    }

    function _qa(address _oracle, address _baseToken) internal view returns (uint256 quote) {
        uint256 oneBaseToken = 10 ** IERC20Metadata(_baseToken).decimals();
        quote = ISiloOracle(_oracle).quote(oneBaseToken, _baseToken);

        string memory baseSymbol = IERC20Metadata(_baseToken).symbol();
        string memory quoteSymbol = IERC20Metadata(ISiloOracle(_oracle).quoteToken()).symbol();

        console2.log("\nQA ------------------------------: %s\n", _oracle);
        console2.log("  Base amount (1 %s): ", baseSymbol);
        console2.log("    ", PriceFormatter.formatPriceInE18(oneBaseToken));
        console2.log("  Quote (%s, 18 decimals): ", quoteSymbol);
        console2.log("    ", PriceFormatter.formatPriceInE18(quote));
    }
}
