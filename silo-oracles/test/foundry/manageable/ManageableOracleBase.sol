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
    function test_ManageableOracle_VERSION() public view{
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
    function test_oracleVerification_succeeds() public view {
        oracle.oracleVerification(ISiloOracle(address(oracleMock)), baseToken);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_onlyOwner_proposeOracle_revert_whenNotOwner
    */
    function test_onlyOwner_proposeOracle_revert_whenNotOwner() public {
        vm.expectRevert(IManageableOracle.OnlyOwner.selector);
        oracle.proposeOracle(ISiloOracle(address(oracleMock)));
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_onlyOwner_proposeTimelock_revert_whenNotOwner
    */
    function test_onlyOwner_proposeTimelock_revert_whenNotOwner() public {
        vm.expectRevert(IManageableOracle.OnlyOwner.selector);
        oracle.proposeTimelock(timelock);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_onlyOwner_proposeTransferOwnership_revert_whenNotOwner
    */
    function test_onlyOwner_proposeTransferOwnership_revert_whenNotOwner() public {
        vm.expectRevert(IManageableOracle.OnlyOwner.selector);
        oracle.proposeTransferOwnership(makeAddr("NewOwner"));
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_onlyOwner_proposeRenounceOwnership_revert_whenNotOwner
    */
    function test_onlyOwner_proposeRenounceOwnership_revert_whenNotOwner() public {
        vm.expectRevert(IManageableOracle.OnlyOwner.selector);
        oracle.proposeRenounceOwnership();
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_onlyOwner_acceptOracle_revert_whenNotOwner
    */
    function test_onlyOwner_acceptOracle_revert_whenNotOwner() public {
        vm.expectRevert(IManageableOracle.OnlyOwner.selector);
        oracle.acceptOracle();
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_onlyOwner_acceptTimelock_revert_whenNotOwner
    */
    function test_onlyOwner_acceptTimelock_revert_whenNotOwner() public {
        vm.expectRevert(IManageableOracle.OnlyOwner.selector);
        oracle.acceptTimelock();
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_onlyOwner_acceptRenounceOwnership_revert_whenNotOwner
    */
    function test_onlyOwner_acceptRenounceOwnership_revert_whenNotOwner() public {
        vm.expectRevert(IManageableOracle.OnlyOwner.selector);
        oracle.acceptRenounceOwnership();
    }
    
    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_onlyOwner_acceptOwnership_revert_whenNotOwner
    */
    function test_onlyOwner_acceptOwnership_revert_whenNotOwner() public {
        vm.prank(owner);
        oracle.proposeTransferOwnership(makeAddr("NewOwner"));

        vm.warp(block.timestamp + timelock + 1);
        vm.prank(owner);
        vm.expectRevert(IManageableOracle.OnlyOwner.selector);
        oracle.acceptOwnership();
        
        vm.expectRevert(IManageableOracle.OnlyOwner.selector);
        oracle.acceptOwnership();
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_onlyOwner_cancelOracle_revert_whenNotOwner
    */
    function test_onlyOwner_cancelOracle_revert_whenNotOwner() public {
        vm.expectRevert(IManageableOracle.OnlyOwner.selector);
        oracle.cancelOracle();
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_onlyOwner_cancelTimelock_revert_whenNotOwner
    */
    function test_onlyOwner_cancelTimelock_revert_whenNotOwner() public {
        vm.expectRevert(IManageableOracle.OnlyOwner.selector);
        oracle.cancelTimelock();
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_onlyOwner_cancelTransferOwnership_revert_whenNotOwner
    */
    function test_onlyOwner_cancelTransferOwnership_revert_whenNotOwner() public {
        vm.expectRevert(IManageableOracle.OnlyOwner.selector);
        oracle.cancelTransferOwnership();
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_onlyOwner_cancelRenounceOwnership_revert_whenNotOwner
    */
    function test_onlyOwner_cancelRenounceOwnership_revert_whenNotOwner() public {
        vm.expectRevert(IManageableOracle.OnlyOwner.selector);
        oracle.cancelRenounceOwnership();
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_proposeOracle_acceptAfterTimelock
    */
    function test_proposeOracle_acceptAfterTimelock() public {
        SiloOracleMock1 otherOracleMock = new SiloOracleMock1();
        otherOracleMock.setQuoteToken(oracleMock.quoteToken());

        uint256 proposeTime = block.timestamp;
        vm.prank(owner);
        oracle.proposeOracle(ISiloOracle(address(otherOracleMock)));

        vm.prank(owner);
        vm.expectRevert(IManageableOracle.TimelockNotExpired.selector);
        oracle.acceptOracle();

        vm.warp(proposeTime + timelock - 1);
        vm.prank(owner);
        vm.expectRevert(IManageableOracle.TimelockNotExpired.selector);
        oracle.acceptOracle();

        vm.warp(proposeTime + timelock);
        vm.expectEmit(true, true, true, true, address(oracle));
        emit IManageableOracle.OracleUpdated(ISiloOracle(address(otherOracleMock)));
        vm.prank(owner);
        oracle.acceptOracle();
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_proposeTimelock_acceptAfterTimelock
    */
    function test_proposeTimelock_acceptAfterTimelock() public {
        uint32 newTimelock = 2 days;
        uint256 proposeTime = block.timestamp;
        vm.prank(owner);
        oracle.proposeTimelock(newTimelock);

        vm.prank(owner);
        vm.expectRevert(IManageableOracle.TimelockNotExpired.selector);
        oracle.acceptTimelock();

        vm.warp(proposeTime + timelock - 1);
        vm.prank(owner);
        vm.expectRevert(IManageableOracle.TimelockNotExpired.selector);
        oracle.acceptTimelock();

        vm.warp(proposeTime + timelock);
        vm.expectEmit(true, true, true, true, address(oracle));
        emit IManageableOracle.TimelockUpdated(newTimelock);
        vm.prank(owner);
        oracle.acceptTimelock();
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_proposeTransferOwnership_acceptOwnershipAfterTimelock
    */
    function test_proposeTransferOwnership_acceptOwnershipAfterTimelock() public {
        address newOwner = makeAddr("NewOwner");
        uint256 proposeTime = block.timestamp;
        vm.prank(owner);
        oracle.proposeTransferOwnership(newOwner);

        vm.prank(newOwner);
        vm.expectRevert(IManageableOracle.TimelockNotExpired.selector);
        oracle.acceptOwnership();

        vm.warp(proposeTime + timelock - 1);
        vm.prank(newOwner);
        vm.expectRevert(IManageableOracle.TimelockNotExpired.selector);
        oracle.acceptOwnership();

        vm.warp(proposeTime + timelock);
        vm.expectEmit(true, true, true, true, address(oracle));
        emit IManageableOracle.OwnershipTransferred(owner, newOwner);
        vm.prank(newOwner);
        oracle.acceptOwnership();
    }

    /*
        FOUNDRY_PROFILE=oracles forge test --mt test_proposeRenounceOwnership_acceptRenounceOwnershipAfterTimelock
    */
    function test_proposeRenounceOwnership_acceptRenounceOwnershipAfterTimelock() public {
        uint256 proposeTime = block.timestamp;
        vm.prank(owner);
        oracle.proposeRenounceOwnership();

        vm.prank(owner);
        vm.expectRevert(IManageableOracle.TimelockNotExpired.selector);
        oracle.acceptRenounceOwnership();

        vm.warp(proposeTime + timelock - 1);
        vm.prank(owner);
        vm.expectRevert(IManageableOracle.TimelockNotExpired.selector);
        oracle.acceptRenounceOwnership();

        vm.warp(proposeTime + timelock);
        vm.expectEmit(true, true, true, false, address(oracle));
        emit IManageableOracle.OwnershipTransferred(owner, address(0));
        vm.prank(owner);
        oracle.acceptRenounceOwnership();
    }
}
