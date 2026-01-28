// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Initializable} from "openzeppelin5-upgradeable/proxy/utils/Initializable.sol";
import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {ManageableOracleFactory} from "silo-oracles/contracts/manageable/ManageableOracleFactory.sol";
import {ManageableOracle} from "silo-oracles/contracts/manageable/ManageableOracle.sol";
import {IManageableOracleFactory} from "silo-oracles/contracts/interfaces/IManageableOracleFactory.sol";
import {IManageableOracle} from "silo-oracles/contracts/interfaces/IManageableOracle.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {SiloOracleMock1} from "silo-oracles/test/foundry/_mocks/silo-oracles/SiloOracleMock1.sol";

// FOUNDRY_PROFILE=oracles forge test --mc ManageableOracleTest
contract ManageableOracleTest is Test {
    address internal _owner = makeAddr("Owner");
    uint32 internal constant _timelock = 1 days;
    address internal constant _baseToken = address(0x1234);

    IManageableOracleFactory internal _factory;
    SiloOracleMock1 internal _oracleMock;

    function setUp() public {
        _oracleMock = new SiloOracleMock1();
        _factory = new ManageableOracleFactory();
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_cannotInitializeTwice_withOracle
        Test that after creating a ManageableOracle, we cannot call initialize again (with oracle)
    */
    function test_ManageableOracle_cannotInitializeTwice_withOracle() public {
        // Create ManageableOracle through factory
        IManageableOracle manageableOracle =
            _factory.create(ISiloOracle(address(_oracleMock)), _owner, _timelock, _baseToken, bytes32(0));

        // Try to call initialize again - should revert with NotInitializing (because __ManageableOracle_init uses onlyInitializing)
        vm.expectRevert(Initializable.NotInitializing.selector);
        manageableOracle.initialize(ISiloOracle(address(_oracleMock)), _owner, _timelock, _baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_cannotInitializeTwice_withFactory
        Test that after creating a ManageableOracle, we cannot call initialize again (with factory)
    */
    function test_ManageableOracle_cannotInitializeTwice_withFactory() public {
        // Create a mock factory that returns an address
        address mockFactory = address(new MockOracleFactory());
        bytes memory initData = abi.encodeWithSelector(MockOracleFactory.create.selector, address(_oracleMock));

        // Create ManageableOracle through factory with underlying oracle factory
        IManageableOracle manageableOracle =
            _factory.create(mockFactory, initData, _owner, _timelock, _baseToken, bytes32(0));

        // Try to call initialize again with factory - should revert with InvalidInitialization (because it uses initializer modifier)
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        manageableOracle.initialize(mockFactory, initData, _owner, _timelock, _baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_cannotInitializeTwice_crossMethod
        Test that after creating a ManageableOracle with oracle, we cannot call initialize with factory
    */
    function test_ManageableOracle_cannotInitializeTwice_crossMethod() public {
        // Create ManageableOracle through factory with oracle
        IManageableOracle manageableOracle =
            _factory.create(ISiloOracle(address(_oracleMock)), _owner, _timelock, _baseToken, bytes32(0));

        // Try to call initialize with factory - should revert with InvalidInitialization
        address mockFactory = address(new MockOracleFactory());
        bytes memory initData = abi.encodeWithSelector(MockOracleFactory.create.selector, address(_oracleMock));

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        manageableOracle.initialize(mockFactory, initData, _owner, _timelock, _baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_cannotInitializeTwice_crossMethodReverse
        Test that after creating a ManageableOracle with factory, we cannot call initialize with oracle
    */
    function test_ManageableOracle_cannotInitializeTwice_crossMethodReverse() public {
        // Create a mock factory that returns an address
        address mockFactory = address(new MockOracleFactory());
        bytes memory initData = abi.encodeWithSelector(MockOracleFactory.create.selector, address(_oracleMock));

        // Create ManageableOracle through factory with underlying oracle factory
        IManageableOracle manageableOracle =
            _factory.create(mockFactory, initData, _owner, _timelock, _baseToken, bytes32(0));

        // Try to call initialize with oracle - should revert with NotInitializing (because __ManageableOracle_init uses onlyInitializing)
        vm.expectRevert(Initializable.NotInitializing.selector);
        manageableOracle.initialize(ISiloOracle(address(_oracleMock)), _owner, _timelock, _baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_cannotInitialize_directlyCreated
        Test that when creating ManageableOracle directly (not through factory), we cannot initialize it
    */
    function test_ManageableOracle_cannotInitialize_directlyCreated() public {
        // Create ManageableOracle directly (not through factory)
        ManageableOracle manageableOracle = new ManageableOracle();

        // Try to call initialize with oracle - should revert with InvalidInitialization (because _disableInitializers was called in constructor)
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        manageableOracle.initialize(ISiloOracle(address(_oracleMock)), _owner, _timelock, _baseToken);

        // Try to call initialize with factory - should also revert with InvalidInitialization
        address mockFactory = address(new MockOracleFactory());
        bytes memory initData = abi.encodeWithSelector(MockOracleFactory.create.selector, address(_oracleMock));

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        manageableOracle.initialize(mockFactory, initData, _owner, _timelock, _baseToken);
    }
}

/* Mock factory for testing - returns the oracle address passed to it */
contract MockOracleFactory {
    function create(address _oracle) external pure returns (address) {
        return _oracle;
    }
}
