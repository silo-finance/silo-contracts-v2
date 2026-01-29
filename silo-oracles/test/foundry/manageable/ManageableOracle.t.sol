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
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";

/*
 FOUNDRY_PROFILE=oracles forge test --mc ManageableOracleTest
*/
contract ManageableOracleTest is Test {
    address internal _owner = makeAddr("Owner");
    uint32 internal constant _timelock = 1 days;
    address internal _baseToken;

    IManageableOracleFactory internal _factory;
    SiloOracleMock1 internal _oracleMock;

    function setUp() public {
        _oracleMock = new SiloOracleMock1();
        _factory = new ManageableOracleFactory();
        _baseToken = address(new MintableToken(18));
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_cannotInitializeTwice_withOracle
        Test that after creating a ManageableOracle, we cannot call initialize again (with oracle)
    */
    function test_ManageableOracle_cannotInitializeTwice_withOracle() public {
        // Create ManageableOracle through factory
        IManageableOracle manageableOracle =
            _factory.create(ISiloOracle(address(_oracleMock)), _owner, _timelock, _baseToken, bytes32(0));

        vm.expectRevert(Initializable.InvalidInitialization.selector);
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

        vm.expectRevert(Initializable.InvalidInitialization.selector);
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

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_directlyCreated_hasZeroOwner
        Test that when creating ManageableOracle directly (not through factory), owner is address(0)
    */
    function test_ManageableOracle_directlyCreated_hasZeroOwner() public {
        ManageableOracle manageableOracle = new ManageableOracle();
        assertEq(manageableOracle.owner(), address(0));
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_initialize_revert_ZeroFactory
        Test that initialize with factory reverts when factory address is zero
    */
    function test_ManageableOracle_initialize_revert_ZeroFactory() public {
        IManageableOracle manageableOracle = _clonedOracle();
        bytes memory initData = abi.encodeWithSelector(MockOracleFactory.create.selector, address(_oracleMock));

        vm.expectRevert(IManageableOracle.ZeroFactory.selector);
        manageableOracle.initialize(address(0), initData, _owner, _timelock, _baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_initialize_revert_FailedToCreateAnOracle
        Test that initialize with factory reverts when factory call fails
    */
    function test_ManageableOracle_initialize_revert_FailedToCreateAnOracle() public {
        IManageableOracle manageableOracle = _clonedOracle();
        address failingFactory = address(new FailingMockOracleFactory());
        bytes memory initData = abi.encodeWithSelector(FailingMockOracleFactory.create.selector);

        vm.expectRevert(IManageableOracle.FailedToCreateAnOracle.selector);
        manageableOracle.initialize(failingFactory, initData, _owner, _timelock, _baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_initialize_revert_ZeroBaseToken
        Test that initialize reverts when baseToken is zero
    */
    function test_ManageableOracle_initialize_revert_ZeroBaseToken() public {
        IManageableOracle manageableOracle = _clonedOracle();

        vm.expectRevert(IManageableOracle.ZeroBaseToken.selector);
        manageableOracle.initialize(ISiloOracle(address(_oracleMock)), _owner, _timelock, address(0));
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_initialize_revert_ZeroOwner
        Test that initialize reverts when owner is zero
    */
    function test_ManageableOracle_initialize_revert_ZeroOwner() public {
        IManageableOracle manageableOracle = _clonedOracle();

        vm.expectRevert(IManageableOracle.ZeroOwner.selector);
        manageableOracle.initialize(ISiloOracle(address(_oracleMock)), address(0), _timelock, _baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_initialize_revert_InvalidTimelock_tooLow
        Test that initialize reverts when timelock is too low
    */
    function test_ManageableOracle_initialize_revert_InvalidTimelock_tooLow() public {
        IManageableOracle manageableOracle = _clonedOracle();
        uint32 minTimelock = ManageableOracle(address(manageableOracle)).MIN_TIMELOCK();
        uint32 timelockTooLow = minTimelock - 1;

        vm.expectRevert(IManageableOracle.InvalidTimelock.selector);
        manageableOracle.initialize(ISiloOracle(address(_oracleMock)), _owner, timelockTooLow, _baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_initialize_revert_InvalidTimelock_tooHigh
        Test that initialize reverts when timelock is too high
    */
    function test_ManageableOracle_initialize_revert_InvalidTimelock_tooHigh() public {
        IManageableOracle manageableOracle = _clonedOracle();
        uint32 maxTimelock = ManageableOracle(address(manageableOracle)).MAX_TIMELOCK();
        uint32 timelockTooHigh = maxTimelock + 1;

        vm.expectRevert(IManageableOracle.InvalidTimelock.selector);
        manageableOracle.initialize(ISiloOracle(address(_oracleMock)), _owner, timelockTooHigh, _baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_initialize_revert_BaseTokenDecimalsMustBeGreaterThanZero
        Test that initialize reverts when baseToken has zero decimals
    */
    function test_ManageableOracle_initialize_revert_BaseTokenDecimalsMustBeGreaterThanZero() public {
        IManageableOracle manageableOracle = _clonedOracle();
        address baseTokenZeroDecimals = address(new MintableToken(0));

        vm.expectRevert(IManageableOracle.BaseTokenDecimalsMustBeGreaterThanZero.selector);
        manageableOracle.initialize(ISiloOracle(address(_oracleMock)), _owner, _timelock, baseTokenZeroDecimals);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_initialize_revert_ZeroOracle
        Test that initialize reverts when oracle address is zero (in oracleVerification when factory returns zero)
    */
    function test_ManageableOracle_initialize_revert_ZeroOracle() public {
        IManageableOracle manageableOracle = _clonedOracle();
        address mockFactory = address(new MockOracleFactory());
        bytes memory initData = abi.encodeWithSelector(MockOracleFactory.create.selector, address(0));

        vm.expectRevert(IManageableOracle.ZeroOracle.selector);
        manageableOracle.initialize(mockFactory, initData, _owner, _timelock, _baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_initialize_revert_OracleQuoteFailed
        Test that initialize reverts when oracle quote returns zero
    */
    function test_ManageableOracle_initialize_revert_OracleQuoteFailed() public {
        IManageableOracle manageableOracle = _clonedOracle();
        address oracleMockZeroQuote = makeAddr("SiloOracleMockZeroQuote");
        vm.mockCall(oracleMockZeroQuote, abi.encodeWithSelector(ISiloOracle.quoteToken.selector), abi.encode(_baseToken));
        vm.mockCall(oracleMockZeroQuote, abi.encodeWithSelector(ISiloOracle.quote.selector, 1e18, _baseToken), abi.encode(0));

        vm.expectRevert(IManageableOracle.OracleQuoteFailed.selector);
        manageableOracle.initialize(ISiloOracle(oracleMockZeroQuote), _owner, _timelock, _baseToken);
    }

    function _clonedOracle() internal returns (IManageableOracle) {
        return IManageableOracle(
            Clones.cloneDeterministic(address(_factory.ORACLE_IMPLEMENTATION()), bytes32(0))
        );
    }
}

/* Mock factory for testing - returns the oracle address passed to it */
contract MockOracleFactory {
    function create(address _oracle) external pure returns (address) {
        return _oracle;
    }
}

/* Mock factory that fails when called */
contract FailingMockOracleFactory {
    function create() external pure {
        revert("Factory call failed");
    }
}
