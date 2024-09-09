// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {IFeesManager, FeesManager} from "ve-silo/contracts/silo-tokens-minter/FeesManager.sol";

contract FeesManagerTest is IntegrationTest {
    event FeesUpdate(uint256 daoFee, uint256 deployerFee);

    function onlyOwnerCanSetFees(
        IFeesManager _manager,
        uint256 _daoFee,
        uint256 _deployerFee,
        address _deployer
    )
        public
    {
        if (_daoFee + _deployerFee > FeesManager(address(_manager)).BPS_MAX()) {
            vm.prank(_deployer);
            vm.expectRevert(abi.encodePacked(IFeesManager.OverallFee.selector));
            _manager.setFees(_daoFee, _deployerFee);
            return;
        }

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _manager.setFees(_daoFee, _deployerFee);

        vm.expectEmit(false, false, true, true);
        emit FeesUpdate(_daoFee, _deployerFee);

        vm.prank(_deployer);
        _manager.setFees(_daoFee, _deployerFee);

        uint256 resolvedDaoFee;
        uint256 resolvedDeployerFee;

        (resolvedDaoFee, resolvedDeployerFee) = _manager.getFees();

        assertEq(resolvedDaoFee, _daoFee, "Invalid DAO fee");
        assertEq(resolvedDeployerFee, _deployerFee, "Invalid deployer fee");
    }
}
