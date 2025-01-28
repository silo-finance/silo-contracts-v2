// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ERC4626OracleFactoryDeploy} from "silo-oracles/deploy/erc4626/ERC4626OracleFactoryDeploy.sol";
import {ERC4626OracleFactory} from "silo-oracles/contracts/erc4626/ERC4626OracleFactory.sol";
import {IERC4626OracleFactory} from "silo-oracles/contracts/interfaces/IERC4626OracleFactory.sol";
import {ERC4626Oracle} from "silo-oracles/contracts/erc4626/ERC4626Oracle.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

// FOUNDRY_PROFILE=oracles forge test --mc ERC4626OracleTest
contract ERC4626OracleTest is Test {
    IERC4626OracleFactory internal _factory;

    address internal _wosVault = 0x9F0dF7799f6FDAd409300080cfF680f5A23df4b1;

    function setUp() public {
        vm.createSelectFork(string(abi.encodePacked(vm.envString("RPC_SONIC"))), 5685582);

        ERC4626OracleFactoryDeploy factoryDeploy = new ERC4626OracleFactoryDeploy();
        factoryDeploy.disableDeploymentsSync();

        _factory = IERC4626OracleFactory(factoryDeploy.run());
    }

    // FOUNDRY_PROFILE=oracles forge test --mt test_ERC4626Oracle_createERC4626Oracle -vvv
    function test_ERC4626Oracle_createERC4626Oracle() public {
        IERC4626 vault = IERC4626(_wosVault);

        ISiloOracle oracle = _factory.createERC4626Oracle(vault);

        assertTrue(ERC4626OracleFactory(address(_factory)).createdInFactory(address(oracle)));
    }

    // FOUNDRY_PROFILE=oracles forge test --mt test_ERC4626Oracle_quote -vvv
    function test_ERC4626Oracle_quote() public {
        IERC4626 vault = IERC4626(_wosVault);

        ISiloOracle oracle = _factory.createERC4626Oracle(vault);

        uint256 quote = oracle.quote(1 ether, address(vault));

        assertEq(quote, vault.convertToAssets(1 ether));
    }

    // FOUNDRY_PROFILE=oracles forge test --mt test_ERC4626Oracle_quote_wrongBaseToken -vvv
    function test_ERC4626Oracle_quote_wrongBaseToken() public {
        IERC4626 vault = IERC4626(_wosVault);

        ISiloOracle oracle = _factory.createERC4626Oracle(vault);

        vm.expectRevert(ERC4626Oracle.AssetNotSupported.selector);
        oracle.quote(1 ether, address(1));
    }

    // FOUNDRY_PROFILE=oracles forge test --mt test_ERC4626Oracle_quoteToken -vvv
    function test_ERC4626Oracle_quoteToken() public {
        IERC4626 vault = IERC4626(_wosVault);

        ISiloOracle oracle = _factory.createERC4626Oracle(vault);

        assertEq(oracle.quoteToken(), address(vault.asset()));
    }

    // FOUNDRY_PROFILE=oracles forge test --mt test_ERC4626Oracle_beforeQuote -vvv
    function test_ERC4626Oracle_beforeQuote() public {
        IERC4626 vault = IERC4626(_wosVault);

        ISiloOracle oracle = _factory.createERC4626Oracle(vault);

        // should not revert
        oracle.beforeQuote(address(vault));
        oracle.beforeQuote(address(1));
    }
}
