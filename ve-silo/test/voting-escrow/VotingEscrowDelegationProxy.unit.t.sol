// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IVeDelegation} from "@balancer-labs/v2-interfaces/contracts/liquidity-mining/IVeDelegation.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {VotingEscrowDelegationProxyDeploy} from "ve-silo/deploy/VotingEscrowDelegationProxyDeploy.s.sol";

import {IVotingEscrowDelegationProxy}
    from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowDelegationProxy.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc VotingEscrowDelegationProxyTest --ffi -vvv
contract VotingEscrowDelegationProxyTest is IntegrationTest {
    address internal _veBoost = makeAddr("VeBoost");

    IVotingEscrowDelegationProxy internal _proxy;

    function setUp() public {
        VotingEscrowDelegationProxyDeploy deploy = new VotingEscrowDelegationProxyDeploy();
        deploy.disableDeploymentsSync();

        setAddress(VeSiloContracts.VE_BOOST, _veBoost);

        _proxy = deploy.run();
    }

    function testEnsureDeployedWithProperParams() public {
        address delegation = address(_proxy.getDelegationImplementation());
        address votingEscrow = address(_proxy.getVotingEscrow());
        
        assertEq(delegation, _veBoost, "Deployed with wrong `delegator` address");

        assertEq(
            votingEscrow,
            getAddress(VeSiloContracts.NULL_VOTING_ESCROW),
            "Deployed with wrong `delegator` address"
        );
    }

    function testPermissions() public {
        // should revert if msg.sender is not the owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _proxy.setDelegation(IVeDelegation(address(1)));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _proxy.killDelegation();
    }

    function testShouldKillDelegation() public {
        address delegation = address(_proxy.getDelegationImplementation());
        assertEq(delegation, _veBoost, "VeBoost should be the `delegation`");

        // should execute transaction
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployer = vm.addr(deployerPrivateKey);

        vm.prank(deployer);
        _proxy.killDelegation();

        delegation = address(_proxy.getDelegationImplementation());
        assertEq(delegation, address(0), "Expected the `delegation` to be an empty");
    }

    function testShouldUpdateDelegation() public {
        address delegation = address(_proxy.getDelegationImplementation());
        assertEq(delegation, _veBoost, "VeBoost should be the `delegation`");

        // should execute transaction
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployer = vm.addr(deployerPrivateKey);

        address veBoost2 = makeAddr("VeBoost2");

        vm.mockCall(
            veBoost2,
            abi.encodeCall(IVeDelegation.adjusted_balance_of, deployer),
            abi.encode(0)
        );

        vm.prank(deployer);
        _proxy.setDelegation(IVeDelegation(veBoost2));

        delegation = address(_proxy.getDelegationImplementation());
        assertEq(delegation, veBoost2, "Failed to update the `delegation`");
    }
}
