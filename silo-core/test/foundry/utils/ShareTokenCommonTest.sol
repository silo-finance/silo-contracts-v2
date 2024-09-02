// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC20PermitUpgradeable} from "openzeppelin5-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloLittleHelper} from "silo-core/test/foundry/_common/SiloLittleHelper.sol";

// solhint-disable ordering

/*
FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc ShareTokenCommonTest
*/
contract ShareTokenCommonTest is SiloLittleHelper, Test, ERC20PermitUpgradeable {
    address public user = makeAddr("someUser");
    address public otherUser = makeAddr("someOtherUser");
    uint256 public mintAmout = 100e18;

    string private constant _NAME = "SiloShareToken";
    string private constant _VERSION = "1";
    bytes32 private constant _TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant TRANSFER_EVENT = keccak256(bytes("Transfer(address,address,uint256)"));

    ISiloConfig public siloConfig;
    address public hookReceiver;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_approveAndAllowance
    */
    function test_approveAndAllowance() public {
        _executeForAllShareTokens(_approveAndAllowance);
    }

    function _approveAndAllowance(IShareToken _shareToken) internal {
        uint256 allowance = _shareToken.allowance(user, otherUser);
        assertEq(allowance, 0, "allowance should be 0");

        uint256 approveAmount = 100e18;

        vm.prank(user);
        _shareToken.approve(otherUser, approveAmount);

        allowance = _shareToken.allowance(user, otherUser);
        assertEq(allowance, approveAmount, "allowance should be equal to approveAmount");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_balanceOfAndTotalSupply
    */
    function test_balanceOfAndTotalSupply() public {
        _executeForAllShareTokens(_balanceOfAndTotalSupply);
    }

    function _balanceOfAndTotalSupply(IShareToken _shareToken) internal {
        ISilo silo = _shareToken.silo();

        vm.prank(address(silo));
        _shareToken.mint(user, user, mintAmout);

        uint256 balance0 = _shareToken.balanceOf(user);
        uint256 totalSupply0 = _shareToken.totalSupply();

        assertEq(balance0, mintAmout, "balance should be equal to mintAmout");
        assertEq(totalSupply0, mintAmout, "totalSupply should be equal to mintAmout");

        (uint256 balance1, uint256 totalSupply1) = _shareToken.balanceOfAndTotalSupply(user);

        assertEq(balance0, balance1, "balances mistmatch");
        assertEq(totalSupply0, totalSupply1, "totalSupply mistmatch");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_shareTokenMintPermissions
    */
    function test_shareTokenMintPermissions() public {
        _executeForAllShareTokens(_shareTokenMintPermissions);
    }

    function _shareTokenMintPermissions(IShareToken _shareToken) internal {
        vm.expectRevert(IShareToken.OnlySilo.selector);
        _shareToken.mint(user, user, mintAmout);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_shareTokenMint
    */
    function test_shareTokenMint() public {
        _executeForAllShareTokens(_shareTokenMint);
    }

    function _shareTokenMint(IShareToken _shareToken) internal {
        ISilo silo = _shareToken.silo();

        vm.recordLogs();

        vm.prank(address(silo));
        _shareToken.mint(user, user, mintAmout);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertTrue(_hasEvent(entries, TRANSFER_EVENT, address(_shareToken)), "Event not emitted");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_burnPermissions
    */
    function test_burnPermissions() public {
        _executeForAllShareTokens(_burnPermissions);
    }

    function _burnPermissions(IShareToken _shareToken) internal {
        vm.expectRevert(IShareToken.OnlySilo.selector);
        _shareToken.burn(user, otherUser, 100e18);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_shareTokenBurn
    */
    function test_shareTokenBurn() public {
        _executeForAllShareTokens(_shareTokenBurn);
    }

    function _shareTokenBurn(IShareToken _shareToken) internal {
        ISilo silo = _shareToken.silo();

        vm.prank(address(silo));
        _shareToken.mint(user, user, mintAmout);

        vm.recordLogs();

        vm.prank(address(silo));
        _shareToken.burn(user, user, mintAmout);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertTrue(_hasEvent(entries, TRANSFER_EVENT, address(_shareToken)), "Event not emitted");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_shareTokenBurnAllowance
    */
    function test_shareTokenBurnAllowance() public {
        _executeForAllCollateralShareTokens(_shareTokenBurnAllowance);
    }

    function _shareTokenBurnAllowance(IShareToken _shareToken) internal {
        ISilo silo = _shareToken.silo();

        vm.prank(address(silo));
        _shareToken.mint(user, user, mintAmout);

        vm.prank(user);
        _shareToken.approve(otherUser, mintAmout);

        vm.expectEmit(true, true, true, false);
        emit Transfer(user, address(0), mintAmout);

        vm.prank(address(silo));
        _shareToken.burn(user, otherUser, mintAmout);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_domainSeparator
    */
    function test_domainSeparator() public {
        _executeForAllShareTokens(_domainSeparator);
    }

    function _domainSeparator(IShareToken _shareToken) internal view {
        bytes32 expectedDomainSeparator = keccak256(abi.encode(
            _TYPE_HASH,
            keccak256(bytes(_NAME)),
            keccak256(bytes(_VERSION)),
            block.chainid,
            address(_shareToken)
        ));

        bytes32 domainSeparator = ERC20PermitUpgradeable(address(_shareToken)).DOMAIN_SEPARATOR();

        assertEq(domainSeparator, expectedDomainSeparator, "unexpected domainSeparator");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_eip712Domain
    */
    function test_eip712Domain() public {
        _executeForAllShareTokens(_eip712Domain);
    }

    function _eip712Domain(IShareToken _shareToken) internal view {
        string memory name;
        string memory version;
        address verifyingContract;

        (, name, version,, verifyingContract,,) = ERC20PermitUpgradeable(address(_shareToken)).eip712Domain();

        assertEq(keccak256(bytes(name)), keccak256(bytes(_NAME)), "name should be equal to _NAME");
        assertEq(keccak256(bytes(version)), keccak256(bytes(_VERSION)), "version should be equal to _VERSION");
        assertEq(verifyingContract, address(_shareToken), "verifyingContract should be equal to _shareToken");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_hookReceiver
    */
    function test_hookReceiver() public {
        _executeForAllShareTokens(_hookReceiver);
    }

    function _hookReceiver(IShareToken _shareToken) internal view {
        address shareTokenHookReceiver = _shareToken.hookReceiver();
        assertEq(shareTokenHookReceiver, address(partialLiquidation), "wrong hookReceiver");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_synchronizeHooksPermissions
    */
    function test_synchronizeHooksPermissions() public {
        _executeForAllShareTokens(_synchronizeHooksPermissions);
    }

    function _synchronizeHooksPermissions(IShareToken _shareToken) internal {
        vm.expectRevert(IShareToken.OnlySilo.selector);
        _shareToken.synchronizeHooks(0, 0);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_hookReceiver
    */
    function test_hookSetupAndSynchronizeHooks() public {
        _executeForAllShareTokens(_hookSetupAndSynchronizeHooks);
    }

    function _hookSetupAndSynchronizeHooks(IShareToken _shareToken) internal {
        ISilo silo = _shareToken.silo();

        IShareToken.HookSetup memory setup = _shareToken.hookSetup();

        uint24 hooksBefore;
        uint24 hooksAfter;

        (hooksBefore, hooksAfter) = IHookReceiver(address(partialLiquidation)).hookReceiverConfig(address(silo));

        assertEq(setup.hooksBefore, hooksBefore, "Should be equal to hooksBefore");
        assertEq(setup.hooksAfter, hooksAfter, "Should be equal to hooksAfter");

        uint24 newBeforeConfig = 55;
        uint24 newAfterConfig = 66;

        vm.prank(address(silo));
        _shareToken.synchronizeHooks(newBeforeConfig, newAfterConfig);

        setup = _shareToken.hookSetup();

        assertEq(setup.hooksBefore, newBeforeConfig, "Should be equal to newBeforeConfig");
        assertEq(setup.hooksAfter, newAfterConfig, "Should be equal to newAfterConfig");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_shareTokenSilo
    */
    function test_shareTokenSilo() public {
        (address protected0, address collateral0, address debt0) = siloConfig.getShareTokens(address(silo0));

        assertEq(address(IShareToken(protected0).silo()), address(silo0), "Should be equal to silo0");
        assertEq(address(IShareToken(collateral0).silo()), address(silo0), "Should be equal to silo0");
        assertEq(address(IShareToken(debt0).silo()), address(silo0), "Should be equal to silo0");

        (address protected1, address collateral1, address debt1) = siloConfig.getShareTokens(address(silo1));

        assertEq(address(IShareToken(protected1).silo()), address(silo1), "Should be equal to silo1");
        assertEq(address(IShareToken(collateral1).silo()), address(silo1), "Should be equal to silo1");
        assertEq(address(IShareToken(debt1).silo()), address(silo1), "Should be equal to silo1");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_shareTokenSiloConfig
    */
    function test_shareTokenSiloConfig() public {
        _executeForAllShareTokens(_shareTokenSiloConfig);
    }

    function _shareTokenSiloConfig(IShareToken _shareToken) internal {
        ISiloConfig shareTokenSiloConfig = _shareToken.siloConfig();
        assertEq(address(shareTokenSiloConfig), address(siloConfig), "Should be equal to siloConfig");
    }

    function _executeForAllShareTokens(function(IShareToken) internal func) internal {
        (address protected0, address collateral0, address debt0) = siloConfig.getShareTokens(address(silo0));
        (address protected1, address collateral1, address debt1) = siloConfig.getShareTokens(address(silo1));

        func(IShareToken(protected0));
        func(IShareToken(collateral0));
        func(IShareToken(debt0));

        func(IShareToken(protected1));
        func(IShareToken(collateral1));
        func(IShareToken(debt1));
    }

    function _executeForAllCollateralShareTokens(function(IShareToken) internal func) internal {
        (address protected0, address collateral0,) = siloConfig.getShareTokens(address(silo0));
        (address protected1, address collateral1,) = siloConfig.getShareTokens(address(silo1));

        func(IShareToken(protected0));
        func(IShareToken(collateral0));

        func(IShareToken(protected1));
        func(IShareToken(collateral1));
    }

    function _executeForAllDebtShareTokens(function(IShareToken) internal func) internal {
        (,, address debt0) = siloConfig.getShareTokens(address(silo0));
        (,, address debt1) = siloConfig.getShareTokens(address(silo1));

        func(IShareToken(debt0));
        func(IShareToken(debt1));
    }

    function _hasEvent(Vm.Log[] memory entries, bytes32 _event, address _emitter) internal pure returns (bool) {
        for(uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == _event && entries[i].emitter == _emitter) {
                return true;
            }
        }

        return false;
    }
}
