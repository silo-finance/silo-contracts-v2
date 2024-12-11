// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";
import {IIncentivesDistributionSolution} from "silo-vaults/contracts/interfaces/IIncentivesDistributionSolution.sol";
import {VaultIncentivesModule} from "silo-vaults/contracts/incentives/VaultIncentivesModule.sol";
import {VaultIncentivesModuleDeploy} from "silo-vaults/deploy/VaultIncentivesModuleDeploy.s.sol";
import {IVaultIncentivesModule} from "silo-vaults/contracts/interfaces/IVaultIncentivesModule.sol";

/*
forge test --mc VaultIncentivesModuleTest -vv
*/
contract VaultIncentivesModuleTest is Test {
    VaultIncentivesModule public incentivesModule;

    address internal _solution1 = makeAddr("Solution1");
    address internal _solution2 = makeAddr("Solution2");

    address internal _logic1 = makeAddr("Logic1");
    address internal _logic2 = makeAddr("Logic2");

    address internal _deployer;

    event IncentivesClaimingLogicAdded(address logic);
    event IncentivesClaimingLogicRemoved(address logic);
    event IncentivesDistributionSolutionAdded(address solution);
    event IncentivesDistributionSolutionRemoved(address solution);

    function setUp() public {
        VaultIncentivesModuleDeploy deployer = new VaultIncentivesModuleDeploy();
        deployer.disableDeploymentsSync();

        incentivesModule = deployer.run();

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);
    }

    /*
    forge test --mt test_addIncentivesClaimingLogicAndGetter -vvv
    */
    function test_addIncentivesClaimingLogicAndGetter() public {
        vm.expectEmit(true, true, true, true);
        emit IncentivesClaimingLogicAdded(_logic1);

        vm.prank(_deployer);
        incentivesModule.addIncentivesClaimingLogic(IIncentivesClaimingLogic(_logic1));

        vm.expectEmit(true, true, true, true);
        emit IncentivesClaimingLogicAdded(_logic2);

        vm.prank(_deployer);
        incentivesModule.addIncentivesClaimingLogic(IIncentivesClaimingLogic(_logic2));

        address[] memory logics = incentivesModule.getIncentivesClaimingLogics();
        assertEq(logics.length, 2);
        assertEq(logics[0], _logic1);
        assertEq(logics[1], _logic2);
    }

    /*
    forge test --mt test_addIncentivesClaimingLogic_alreadyAdded -vvv
    */
    function test_addIncentivesClaimingLogic_alreadyAdded() public {
        vm.prank(_deployer);
        incentivesModule.addIncentivesClaimingLogic(IIncentivesClaimingLogic(_logic1));

        vm.expectRevert(IVaultIncentivesModule.LogicAlreadyAdded.selector);
        vm.prank(_deployer);
        incentivesModule.addIncentivesClaimingLogic(IIncentivesClaimingLogic(_logic1));
    }

    /*
    forge test --mt test_addIncentivesClaimingLogic_zeroAddress -vvv
    */
    function test_addIncentivesClaimingLogic_zeroAddress() public {
        vm.expectRevert(IVaultIncentivesModule.AddressZero.selector);
        vm.prank(_deployer);
        incentivesModule.addIncentivesClaimingLogic(IIncentivesClaimingLogic(address(0)));
    }

    /*
    forge test --mt test_addIncentivesClaimingLogic_onlyOwner -vvv
    */
    function test_addIncentivesClaimingLogic_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        incentivesModule.addIncentivesClaimingLogic(IIncentivesClaimingLogic(_logic1));
    }

    /*
    forge test --mt test_removeIncentivesClaimingLogic -vvv
    */
    function test_removeIncentivesClaimingLogic() public {
        vm.prank(_deployer);
        incentivesModule.addIncentivesClaimingLogic(IIncentivesClaimingLogic(_logic1));

        address[] memory logics = incentivesModule.getIncentivesClaimingLogics();
        assertEq(logics.length, 1);

        vm.expectEmit(true, true, true, true);
        emit IncentivesClaimingLogicRemoved(_logic1);

        vm.prank(_deployer);
        incentivesModule.removeIncentivesClaimingLogic(IIncentivesClaimingLogic(_logic1));

        logics = incentivesModule.getIncentivesClaimingLogics();
        assertEq(logics.length, 0);
    }

    /*
    forge test --mt test_removeIncentivesClaimingLogic_notAdded -vvv
    */
    function test_removeIncentivesClaimingLogic_notAdded() public {
        vm.expectRevert(IVaultIncentivesModule.LogicNotFound.selector);
        vm.prank(_deployer);
        incentivesModule.removeIncentivesClaimingLogic(IIncentivesClaimingLogic(_logic1));
    }

    /*
    forge test --mt test_removeIncentivesClaimingLogic_onlyOwner -vvv
    */
    function test_removeIncentivesClaimingLogic_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        incentivesModule.removeIncentivesClaimingLogic(IIncentivesClaimingLogic(_logic1));
    }

    /*
    forge test --mt test_addIncentivesDistributionSolutionAndGetter -vvv
    */
    function test_addIncentivesDistributionSolutionAndGetter() public {
        vm.expectEmit(true, true, true, true);
        emit IncentivesDistributionSolutionAdded(_solution1);

        vm.prank(_deployer);
        incentivesModule.addIncentivesDistributionSolution(IIncentivesDistributionSolution(_solution1));

        vm.expectEmit(true, true, true, true);
        emit IncentivesDistributionSolutionAdded(_solution2);

        vm.prank(_deployer);
        incentivesModule.addIncentivesDistributionSolution(IIncentivesDistributionSolution(_solution2));

        address[] memory solutions = incentivesModule.getIncentivesDistributionSolutions();

        assertEq(solutions.length, 2);
        assertEq(solutions[0], _solution1);
        assertEq(solutions[1], _solution2);
    }

    /*
    forge test --mt test_addIncentivesDistributionSolution_alreadyAdded -vvv
    */
    function test_addIncentivesDistributionSolution_alreadyAdded() public {
        vm.prank(_deployer);
        incentivesModule.addIncentivesDistributionSolution(IIncentivesDistributionSolution(_solution1));

        vm.expectRevert(IVaultIncentivesModule.SolutionAlreadyAdded.selector);
        vm.prank(_deployer);
        incentivesModule.addIncentivesDistributionSolution(IIncentivesDistributionSolution(_solution1));
    }

    /*
    forge test --mt test_addIncentivesDistributionSolution_zeroAddress -vvv
    */
    function test_addIncentivesDistributionSolution_zeroAddress() public {
        vm.expectRevert(IVaultIncentivesModule.AddressZero.selector);
        vm.prank(_deployer);
        incentivesModule.addIncentivesDistributionSolution(IIncentivesDistributionSolution(address(0)));
    }

    /*
    forge test --mt test_addIncentivesDistributionSolution_onlyOwner -vvv
    */
    function test_addIncentivesDistributionSolution_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        incentivesModule.addIncentivesDistributionSolution(IIncentivesDistributionSolution(_solution1));
    }

    /*
    forge test --mt test_removeIncentivesDistributionSolution -vvv
    */
    function test_removeIncentivesDistributionSolution() public {
        vm.prank(_deployer);
        incentivesModule.addIncentivesDistributionSolution(IIncentivesDistributionSolution(_solution1));

        address[] memory solutions = incentivesModule.getIncentivesDistributionSolutions();
        assertEq(solutions.length, 1);

        vm.expectEmit(true, true, true, true);
        emit IncentivesDistributionSolutionRemoved(_solution1);

        vm.prank(_deployer);
        incentivesModule.removeIncentivesDistributionSolution(IIncentivesDistributionSolution(_solution1));

        solutions = incentivesModule.getIncentivesDistributionSolutions();
        assertEq(solutions.length, 0);
    }

    /*
    forge test --mt test_removeIncentivesDistributionSolution_notAdded -vvv
    */
    function test_removeIncentivesDistributionSolution_notAdded() public {
        vm.expectRevert(IVaultIncentivesModule.SolutionNotFound.selector);
        vm.prank(_deployer);
        incentivesModule.removeIncentivesDistributionSolution(IIncentivesDistributionSolution(_solution1));
    }

    /*
    forge test --mt test_removeIncentivesDistributionSolution_onlyOwner -vvv
    */
    function test_removeIncentivesDistributionSolution_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        incentivesModule.removeIncentivesDistributionSolution(IIncentivesDistributionSolution(_solution1));
    }

    /*
    forge test --mt test_vaultIncentivesModule_ownershipTransfer -vvv
    */
    function test_vaultIncentivesModule_ownershipTransfer() public {
        address newOwner = makeAddr("NewOwner");

        Ownable2Step module = Ownable2Step(address(incentivesModule));

        vm.prank(_deployer);
        module.transferOwnership(newOwner);

        assertEq(module.pendingOwner(), newOwner);

        vm.prank(newOwner);
        module.acceptOwnership();

        assertEq(module.owner(), newOwner);
    }
}
