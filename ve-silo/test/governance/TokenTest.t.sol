// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ISiloToken} from "ve-silo/contracts/governance/interfaces/ISiloToken.sol";
import {MiloTokenDeploy} from "ve-silo/deploy/MiloTokenDeploy.s.sol";

abstract contract TokenTest is IntegrationTest {
    ISiloToken internal _token;
    address internal _deployer;

    function setUp() public {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);

        vm.createSelectFork(
            getChainRpcUrl(_network()),
            _forkingBlockNumber()
        );

        _deployToken();
    }

    function testEnsureDeployedWithCorrectConfigurations() public view {
        assertEq(_token.symbol(), _symbol(), "An invalid symbol after deployment");
        assertEq(_token.name(), _name(), "An invalid name after deployment");
        assertEq(_token.decimals(), _decimals(), "An invalid decimals after deployment");
    }

    function testOnlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _token.mint(address(this), 1000);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _token.burn(1000);
    }

    function testOwnerCanMintAndBurn() public {
        assertEq(_token.balanceOf(_deployer), 0, "An invalid balance before minting");

        uint256 tokensAmount = 10_000_000_000e18;

        vm.prank(_deployer);
        _token.mint(_deployer, tokensAmount);
        assertEq(_token.balanceOf(_deployer), tokensAmount, "An invalid balance after minting");

        vm.prank(_deployer);
        _token.burn(tokensAmount);
        assertEq(_token.balanceOf(_deployer), 0, "An invalid balance after burning");
    }

    function _deployToken() internal virtual {}
    function _network() internal virtual pure returns (string memory) {}
    function _forkingBlockNumber() internal virtual pure returns (uint256) {}
    function _symbol() internal virtual pure returns (string memory) {}
    function _name() internal virtual pure returns (string memory) {}
    function _decimals() internal virtual pure returns (uint8) {}
}
