// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {OracleForwarderFactoryDeploy} from "silo-oracles/deploy/OracleForwarderFactoryDeploy.sol";
import {OracleForwarderFactory} from "silo-oracles/contracts/forwarder/OracleForwarderFactory.sol";
import {IOracleForwarderFactory} from "silo-oracles/contracts/interfaces/IOracleForwarderFactory.sol";
import {IOracleForwarder} from "silo-oracles/contracts/interfaces/IOracleForwarder.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {SiloOracleMock1} from "silo-oracles/test/foundry/_mocks/silo-oracles/SiloOracleMock1.sol";
import {SiloOracleMock2} from "silo-oracles/test/foundry/_mocks/silo-oracles/SiloOracleMock2.sol";

// FOUNDRY_PROFILE=oracles forge test --mc OracleForwarderTest
contract OracleForwarderTest is Test {
    address internal _owner = makeAddr("Owner");

    SiloOracleMock1 internal _oracleMock1;
    SiloOracleMock2 internal _oracleMock2;

    IOracleForwarder internal _oracleForwarder;

    event OracleSet(ISiloOracle indexed oracle);

    event BeforeQuoteSiloOracleMock1();
    event BeforeQuoteSiloOracleMock2();

    function setUp() public {
        _oracleMock1 = new SiloOracleMock1();
        _oracleMock2 = new SiloOracleMock2();

        OracleForwarderFactoryDeploy factoryDeploy = new OracleForwarderFactoryDeploy();
        factoryDeploy.disableDeploymentsSync();

        address factory = factoryDeploy.run();

        _oracleForwarder = IOracleForwarderFactory(factory).createOracleForwarder(
            ISiloOracle(address(_oracleMock1)),
            _owner
        );
    }

    // FOUNDRY_PROFILE=oracles forge test --mt test_OracleForwarder_setOracle
    function test_OracleForwarder_setOracle_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _oracleForwarder.setOracle(ISiloOracle(address(_oracleMock2)));
    }

    // FOUNDRY_PROFILE=oracles forge test --mt test_OracleForwarder_setOracle
    function test_OracleForwarder_setOracle() public {
        address oracleBefore = address(_oracleForwarder.oracle());

        assertEq(oracleBefore, address(_oracleMock1));

        vm.expectEmit(true, true, true, true);
        emit OracleSet(ISiloOracle(address(_oracleMock2)));

        vm.prank(_owner);
        _oracleForwarder.setOracle(ISiloOracle(address(_oracleMock2)));

        assertEq(address(_oracleForwarder.oracle()), address(_oracleMock2));
    }

    // FOUNDRY_PROFILE=oracles forge test --mt test_OracleForwarder_setOracle_quoteTokenMustBeTheSame
    function test_OracleForwarder_setOracle_quoteTokenMustBeTheSame() public {
        address quoteToken = makeAddr("quoteToken");

        vm.mockCall(
            address(_oracleMock2),
            abi.encodeWithSelector(ISiloOracle.quoteToken.selector),
            abi.encode(quoteToken)
        );

        vm.expectRevert(abi.encodeWithSelector(IOracleForwarder.QuoteTokenMustBeTheSame.selector));
        vm.prank(_owner);
        _oracleForwarder.setOracle(ISiloOracle(address(_oracleMock2)));
    }

    // FOUNDRY_PROFILE=oracles forge test --mt test_OracleForwarder_beforeQuote
    function test_OracleForwarder_beforeQuote() public {
        ISiloOracle forwarder = ISiloOracle(address(_oracleForwarder));

        vm.expectEmit(true, true, true, true);
        emit BeforeQuoteSiloOracleMock1();

        forwarder.beforeQuote(address(0));

        vm.prank(_owner);
        _oracleForwarder.setOracle(ISiloOracle(address(_oracleMock2)));

        vm.expectEmit(true, true, true, true);
        emit BeforeQuoteSiloOracleMock2();

        forwarder.beforeQuote(address(0));
    }

    // FOUNDRY_PROFILE=oracles forge test --mt test_OracleForwarder_quote
    function test_OracleForwarder_quote() public {
        ISiloOracle forwarder = ISiloOracle(address(_oracleForwarder));

        uint256 quote1 = forwarder.quote(1, address(0));

        assertEq(quote1, _oracleMock1.QUOTE_AMOUNT());

        vm.prank(_owner);
        _oracleForwarder.setOracle(ISiloOracle(address(_oracleMock2)));

        uint256 quote2 = forwarder.quote(1, address(0));
        assertEq(quote2, _oracleMock2.QUOTE_AMOUNT());
    }

    // FOUNDRY_PROFILE=oracles forge test --mt test_OracleForwarder_quoteToken
    function test_OracleForwarder_quoteToken() public {
        ISiloOracle forwarder = ISiloOracle(address(_oracleForwarder));

        assertEq(forwarder.quoteToken(), _oracleMock1.tokenAsQuote());

        vm.prank(_owner);
        _oracleForwarder.setOracle(ISiloOracle(address(_oracleMock2)));

        assertEq(forwarder.quoteToken(), _oracleMock2.tokenAsQuote());
    }
}
