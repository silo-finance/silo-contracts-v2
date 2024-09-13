// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {BalancerTokenAdmin, IBalancerToken}
    from "ve-silo/contracts/silo-tokens-minter/BalancerTokenAdmin.sol";

import {Manageable} from "ve-silo/contracts/access/Manageable.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc BalancerTokenAdminTest --ffi -vvv
contract BalancerTokenAdminTest is IntegrationTest {
    uint256 constant internal _INITIAL_SUPPLY = 1000;

    BalancerTokenAdmin internal _tokenAdmin;
    address internal _token = makeAddr("Token");
    address internal _deployer = makeAddr("Deployer");

    event MiningParametersUpdated(uint256 rate, uint256 supply);

    function setUp() public {
        vm.prank(_deployer);
        _tokenAdmin = new BalancerTokenAdmin(IBalancerToken(_token));
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testBalanceTokenAdmintActivatePermissions --ffi -vvv
    function testBalanceTokenAdmintActivatePermissions() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _tokenAdmin.activate();
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testFailToActivateIfIsNotTokenOwner --ffi -vvv
    function testFailToActivateIfIsNotTokenOwner() public {
        vm.expectRevert("BalancerTokenAdmin is not a minter");

        vm.prank(_deployer);
        _tokenAdmin.activate();
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testBalanceTokenAdmintOwnerCanActivate --ffi -vvv
    function testBalanceTokenAdmintOwnerCanActivate() public {
        _activate();
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testBalanceTokenAdmintFailToActivateTwice --ffi -vvv
    function testBalanceTokenAdmintFailToActivateTwice() public {
        _activate();

        vm.expectRevert("Already activated");

         vm.prank(_deployer);
        _tokenAdmin.activate();
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testBalanceTokenAdmintInitialParams --ffi -vvv
    function testBalanceTokenAdmintInitialParams() public {
        _activate();

        assertEq(_tokenAdmin.getStartEpochTime(), block.timestamp);
        assertEq(_tokenAdmin.getStartEpochSupply(), _INITIAL_SUPPLY);
        assertEq(_tokenAdmin.getInflationRate(), _tokenAdmin.INITIAL_RATE());
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testMiningParametersUpdateRevertEpoch --ffi -vvv
    function testMiningParametersUpdateRevertEpoch() public {
        _activate();

        vm.expectRevert("Epoch has not finished yet");
        _tokenAdmin.updateMiningParameters();
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testMiningParametersUpdateEpochFinished --ffi -vvv
    function testMiningParametersUpdateEpochFinished() public {
        _activate();

        uint256 futureEpochTime = _tokenAdmin.getFutureEpochTime();

        vm.warp(futureEpochTime + 1);

        uint256 currentRate = _tokenAdmin.getInflationRate();
        uint256 rateReduction = _tokenAdmin.RATE_REDUCTION_COEFFICIENT();

        uint256 epxectedSupply = _INITIAL_SUPPLY + currentRate * _tokenAdmin.RATE_REDUCTION_TIME();
        uint256 expectedRate = currentRate * 1e18 / rateReduction;

        vm.expectEmit(false, false, true, true);

        emit MiningParametersUpdated(expectedRate, epxectedSupply);

        _tokenAdmin.updateMiningParameters();
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testBalanceTokenAdminMintPermissions --ffi -vvv
    function testBalanceTokenAdminMintPermissions() public {
        _activate();

        vm.expectRevert(Manageable.OnlyManager.selector);
        _tokenAdmin.mint(address(0), 0);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testBalanceTokenAdminMintAmountExceeds --ffi -vvv
    function testBalanceTokenAdminMintAmountExceeds() public {
        _activate();

        address to = makeAddr("To");
        uint256 amount = 100;

        vm.expectRevert("Mint amount exceeds remaining available supply");

        vm.prank(_deployer);
        _tokenAdmin.mint(to, amount);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testBalanceTokenAdminMint --ffi -vvv
    function testBalanceTokenAdminMint() public {
        _activate();

        vm.warp(block.timestamp + 30 days);

        address to = makeAddr("To");
        uint256 amount = 100;

        bytes memory payload = abi.encodeWithSelector(_tokenAdmin.mint.selector, to, amount);

        vm.mockCall(
            _token,
            payload,
            abi.encode(true)
        );

        vm.expectCall(_token, payload);

        vm.prank(_deployer);
        _tokenAdmin.mint(to, amount);
    }

    function _activate() internal {
        _mockToken();

        vm.expectEmit(false, false, true, true);

        emit MiningParametersUpdated(_tokenAdmin.INITIAL_RATE(), _INITIAL_SUPPLY);

        vm.prank(_deployer);
        _tokenAdmin.activate();
    }

    function _mockToken() internal {
        vm.mockCall(
            _token,
            abi.encodeWithSelector(Ownable.owner.selector),
            abi.encode(address(_tokenAdmin))
        );

        vm.mockCall(
            _token,
            abi.encodeWithSelector(IERC20.totalSupply.selector),
            abi.encode(_INITIAL_SUPPLY)
        );
    }
}
