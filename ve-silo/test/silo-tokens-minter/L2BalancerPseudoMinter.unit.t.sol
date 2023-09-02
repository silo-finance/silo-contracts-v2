// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";

import {L2BalancerPseudoMinterDeploy, IL2BalancerPseudoMinter}
    from "ve-silo/deploy/L2BalancerPseudoMinterDeploy.s.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc L2BalancerPseudoMinterTest --ffi -vvv
contract L2BalancerPseudoMinterTest is IntegrationTest {
    address internal _siloTokenAddr = makeAddr("Silo token mock");
    
    IL2BalancerPseudoMinter internal _minter;

    ILiquidityGaugeFactory internal _liquidityGaugeFactory =
        ILiquidityGaugeFactory(makeAddr("Liquidity gauge factory"));

    function setUp() public {
        L2BalancerPseudoMinterDeploy deploy = new L2BalancerPseudoMinterDeploy();
        deploy.disableDeploymentsSync();

        setAddress(SILO_TOKEN, _siloTokenAddr);

        _minter = deploy.run();
    }

    function testAddGaugeFactoryPermissions() public {
        vm.expectRevert("Ownable: caller is not the owner");
        _minter.addGaugeFactory(_liquidityGaugeFactory);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.prank(deployer);
        _minter.addGaugeFactory(_liquidityGaugeFactory);

        assertTrue(_minter.isValidGaugeFactory(_liquidityGaugeFactory), "Failed to add a factory");
    }

    function testRemoveGaugeFactoryPermissions() public {
        vm.expectRevert("Ownable: caller is not the owner");
        _minter.removeGaugeFactory(_liquidityGaugeFactory);


        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.prank(deployer);
        vm.expectRevert("FACTORY_NOT_ADDED"); // we only want to check if we have permissions
        _minter.removeGaugeFactory(_liquidityGaugeFactory);
    }
}
