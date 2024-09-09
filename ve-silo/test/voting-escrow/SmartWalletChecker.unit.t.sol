// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {SmartWalletChecker} from "ve-silo/contracts/voting-escrow/SmartWalletChecker.sol";
import {SmartWalletCheckerDeploy} from "ve-silo/deploy/SmartWalletCheckerDeploy.s.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc SmartWalletCheckerTest --ffi -vvv
contract SmartWalletCheckerTest is IntegrationTest {
    SmartWalletChecker internal _smartWalletChecker;

    address internal _testAddr = makeAddr("Test address");
    address internal _deployer;

    event ContractAddressAdded(address contractAddress);
    event ContractAddressRemoved(address contractAddress);

    function setUp() public {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);

        SmartWalletCheckerDeploy deploy = new SmartWalletCheckerDeploy();
        deploy.disableDeploymentsSync();

        _smartWalletChecker = SmartWalletChecker(address(deploy.run()));
    }

    function testAllowlistAddressPermissions() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _smartWalletChecker.allowlistAddress(_testAddr);

        _allowlistAddress();
    }

    function testDenylistAddressPermissions() public {
        _allowlistAddress();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _smartWalletChecker.denylistAddress(_testAddr);

        _denylistAddress();
    }

    function testGetters() public {
        _allowlistAddress();

        uint256 length = _smartWalletChecker.getAllowlistedAddressesLength();
        assertEq(length, 1, "Expect to have one address");

        bool allowed = _smartWalletChecker.check(_testAddr);
        assertTrue(allowed, "Expect wallet to be allowed");
    }

    function _allowlistAddress() internal {
        vm.expectEmit(false, false, false, true);
        emit ContractAddressAdded(_testAddr);

        vm.prank(_deployer);
        _smartWalletChecker.allowlistAddress(_testAddr);
    }

    function _denylistAddress() internal {
        vm.expectEmit(false, false, false, true);
        emit ContractAddressRemoved(_testAddr);

        vm.prank(_deployer);
        _smartWalletChecker.denylistAddress(_testAddr);
    }
}
