// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {ManageableOracleFactory} from "silo-oracles/contracts/manageable/ManageableOracleFactory.sol";
import {IManageableOracleFactory} from "silo-oracles/contracts/interfaces/IManageableOracleFactory.sol";
import {IManageableOracle} from "silo-oracles/contracts/interfaces/IManageableOracle.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IVersioned} from "silo-core/contracts/interfaces/IVersioned.sol";

import {SiloOracleMock1} from "silo-oracles/test/foundry/_mocks/silo-oracles/SiloOracleMock1.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";
import {MockOracleFactory} from "silo-oracles/test/foundry/manageable/common/MockOracleFactory.sol";
/*
 FOUNDRY_PROFILE=oracles forge test --mc ManageableOracleBase
 (base is abstract; run ManageableOracleBaseWithOracleTest or ManageableOracleBaseWithFactoryTest)
*/
abstract contract ManageableOracleBase is Test {
    error OracleCustomError();
    address internal owner = makeAddr("Owner");
    uint32 internal constant timelock = 1 days;
    address internal baseToken;

    IManageableOracleFactory internal factory;
    SiloOracleMock1 internal oracleMock;
    IManageableOracle internal oracle;

    function setUp() public {
        oracleMock = new SiloOracleMock1();
        factory = new ManageableOracleFactory();
        baseToken = address(new MintableToken(18));
        oracle = _createManageableOracle();
    }

    /// @return manageableOracle Created oracle (via create with oracle or create with factory)
    function _createManageableOracle() internal virtual returns (IManageableOracle manageableOracle);

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_creation_emitsAllEvents
    */
    function test_ManageableOracle_creation_emitsAllEvents() public {
        address predictedAddress = factory.predictAddress(address(this), bytes32(0));

        vm.expectEmit(true, true, true, true, address(factory));
        emit IManageableOracleFactory.ManageableOracleCreated(predictedAddress, owner);

        vm.expectEmit(true, true, true, true);
        emit IManageableOracle.OwnershipTransferred(address(0), owner);

        vm.expectEmit(true, true, true, true);
        emit IManageableOracle.OracleUpdated(ISiloOracle(address(oracleMock)));

        vm.expectEmit(true, true, true, true);
        emit IManageableOracle.TimelockUpdated(timelock);

        _createManageableOracle();
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_ManageableOracle_VERSION
    */
    function test_ManageableOracle_VERSION() public {
        assertEq(IVersioned(address(oracle)).VERSION(), "ManageableOracle 4.0.0");
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_oracleVerification_revert_ZeroOracle
    */
    function test_oracleVerification_revert_ZeroOracle() public {
        vm.expectRevert(IManageableOracle.ZeroOracle.selector);
        oracle.oracleVerification(ISiloOracle(address(0)), baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_oracleVerification_revert_QuoteTokenMustBeTheSame
    */
    function test_oracleVerification_revert_QuoteTokenMustBeTheSame() public {
        address wrongQuoteTokenOracle = makeAddr("wrongQuoteTokenOracle");
        
        vm.mockCall(
            wrongQuoteTokenOracle,
            abi.encodeWithSelector(ISiloOracle.quoteToken.selector),
            abi.encode(makeAddr("differentQuoteToken"))
        );
        
        vm.expectRevert(IManageableOracle.QuoteTokenMustBeTheSame.selector);
        oracle.oracleVerification(ISiloOracle(wrongQuoteTokenOracle), baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_oracleVerification_revert_OracleQuoteFailed
    */
    function test_oracleVerification_revert_OracleQuoteFailed() public {
        address zeroQuoteOracle = makeAddr("zeroQuoteOracle");
        
        vm.mockCall(
            zeroQuoteOracle,
            abi.encodeWithSelector(ISiloOracle.quoteToken.selector),
            abi.encode(oracleMock.quoteToken())
        );
        
        vm.mockCall(
            zeroQuoteOracle,
            abi.encodeWithSelector(ISiloOracle.quote.selector, 10 ** 18, baseToken),
            abi.encode(uint256(0))
        );
        
        vm.expectRevert(IManageableOracle.OracleQuoteFailed.selector);
        oracle.oracleVerification(ISiloOracle(zeroQuoteOracle), baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_oracleVerification_revert_whenOracleReverts
    */
    function test_oracleVerification_revert_whenOracleReverts() public {
        address revertingOracle = makeAddr("revertingOracle");
        vm.mockCall(
            revertingOracle,
            abi.encodeWithSelector(ISiloOracle.quoteToken.selector),
            abi.encode(oracleMock.quoteToken())
        );
        vm.mockCallRevert(
            revertingOracle,
            abi.encodeWithSelector(ISiloOracle.quote.selector, 10 ** 18, baseToken),
            ""
        );
        vm.expectRevert(IManageableOracle.OracleQuoteFailed.selector);
        oracle.oracleVerification(ISiloOracle(revertingOracle), baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_oracleVerification_revert_propagatesCustomError
    */
    function test_oracleVerification_revert_propagatesCustomError() public {
        address customErrorOracle = makeAddr("customErrorOracle");
        vm.mockCall(
            customErrorOracle,
            abi.encodeWithSelector(ISiloOracle.quoteToken.selector),
            abi.encode(oracleMock.quoteToken())
        );
        vm.mockCallRevert(
            customErrorOracle,
            abi.encodeWithSelector(ISiloOracle.quote.selector, 10 ** 18, baseToken),
            abi.encodeWithSelector(OracleCustomError.selector)
        );
        vm.expectRevert(OracleCustomError.selector);
        oracle.oracleVerification(ISiloOracle(customErrorOracle), baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_oracleVerification_succeeds
    */
    function test_oracleVerification_succeeds() public {
        oracle.oracleVerification(ISiloOracle(address(oracleMock)), baseToken);
    }
}
