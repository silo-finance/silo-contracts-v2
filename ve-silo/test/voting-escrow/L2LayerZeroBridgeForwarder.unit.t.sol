// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {IL2LayerZeroBridgeForwarder, IL2LayerZeroDelegation}
    from "ve-silo/contracts/voting-escrow/interfaces/IL2LayerZeroBridgeForwarder.sol";

import {L2LayerZeroBridgeForwarderDeploy} from "ve-silo/deploy/L2LayerZeroBridgeForwarderDeploy.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc L2LayerZeroBridgeForwarderTest --ffi -vvv
contract L2LayerZeroBridgeForwarderTest is IntegrationTest {
    IL2LayerZeroBridgeForwarder internal _forwarder;

    function setUp() public {
        L2LayerZeroBridgeForwarderDeploy deploy = new L2LayerZeroBridgeForwarderDeploy();
        deploy.disableDeploymentsSync();

        _forwarder = deploy.run();
    }

    function testPermissions() public {
        IL2LayerZeroDelegation implementation = IL2LayerZeroDelegation(makeAddr("Implementation"));

        vm.expectRevert("Ownable: caller is not the owner");
        _forwarder.setDelegation(implementation);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.prank(deployer);
        _forwarder.setDelegation(implementation);

        assertEq(
            address(_forwarder.getDelegationImplementation()),
            address(implementation),
            "Wrong implementation"
        );
    }
}
