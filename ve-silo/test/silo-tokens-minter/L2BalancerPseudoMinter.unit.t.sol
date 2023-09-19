// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ERC20PresetMinterPauser, IERC20} from "openzeppelin-contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {ISiloChildChainGauge} from "ve-silo/contracts/gauges/interfaces/ISiloChildChainGauge.sol";
import {ISiloWithFeeDetails as ISilo} from "ve-silo/contracts/silo-tokens-minter/interfaces/ISiloWithFeeDetails.sol";

import {L2BalancerPseudoMinterDeploy, IL2BalancerPseudoMinter}
    from "ve-silo/deploy/L2BalancerPseudoMinterDeploy.s.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc L2BalancerPseudoMinterTest --ffi -vvv
contract L2BalancerPseudoMinterTest is IntegrationTest {
    uint256 internal constant _BOB_BALANCE = 1e18;
    uint256 internal constant _DAO_FEE = 1e3; // 10%
    uint256 internal constant _DEPLOYER_FEE = 2e3; // 20%

    ERC20PresetMinterPauser internal _siloToken;
    IL2BalancerPseudoMinter internal _minter;
    ILiquidityGaugeFactory internal _liquidityGaugeFactory =
        ILiquidityGaugeFactory(makeAddr("Liquidity gauge factory"));

    address internal _gauge = makeAddr("Gauge");
    address internal _bob = makeAddr("Bob");
    address internal _silo = makeAddr("Silo");
    address internal _daoFeeReceiver = makeAddr("DAO fee receiver");
    address internal _deployerFeeReceiver = makeAddr("Deployer fee receiver");
    address internal _deployer;

    function setUp() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        _deployer = vm.addr(deployerPrivateKey);

        L2BalancerPseudoMinterDeploy deploy = new L2BalancerPseudoMinterDeploy();
        deploy.disableDeploymentsSync();

        _siloToken = new ERC20PresetMinterPauser("Test", "T");

        setAddress(SILO_TOKEN, address(_siloToken));

        _minter = deploy.run();

        _mockCallsForTest();

        _siloToken.mint(address(_minter), _BOB_BALANCE);
    }

    function testAddGaugeFactoryPermissions() public {
        vm.expectRevert("Ownable: caller is not the owner");
        _minter.addGaugeFactory(_liquidityGaugeFactory);

        vm.prank(_deployer);
        _minter.addGaugeFactory(_liquidityGaugeFactory);

        assertTrue(_minter.isValidGaugeFactory(_liquidityGaugeFactory), "Failed to add a factory");
    }

    function testRemoveGaugeFactoryPermissions() public {
        vm.expectRevert("Ownable: caller is not the owner");
        _minter.removeGaugeFactory(_liquidityGaugeFactory);

        vm.prank(_deployer);
        vm.expectRevert("FACTORY_NOT_ADDED"); // we only want to check if we have permissions
        _minter.removeGaugeFactory(_liquidityGaugeFactory);
    }

        /// @notice Should mint tokens
    function testMintForNoFees() public {
        vm.prank(_deployer);
        _minter.addGaugeFactory(_liquidityGaugeFactory);

        // without fees
        vm.mockCall(
            _silo,
            abi.encodeWithSelector(ISilo.getFeesAndFeeReceivers.selector),
            abi.encode(
                address(0),
                address(0),
                0,
                0
            )
        );

        IERC20 siloToken = IERC20(getAddress(SILO_TOKEN));

        assertEq(siloToken.balanceOf(_bob), 0);

        _mintFor();

        assertEq(siloToken.balanceOf(_bob), _BOB_BALANCE);
    }

    /// @notice Should mint tokens and collect fees
    function testMintForWithFees() public {
        vm.prank(_deployer);
        _minter.addGaugeFactory(_liquidityGaugeFactory);

        // with fees
        // 10% - to DAO
        // 20% - to deployer
        vm.mockCall(
            _silo,
            abi.encodeWithSelector(ISilo.getFeesAndFeeReceivers.selector),
            abi.encode(
                _daoFeeReceiver,
                _deployerFeeReceiver,
                _DAO_FEE,
                _DEPLOYER_FEE
            )
        );

        IERC20 siloToken = IERC20(getAddress(SILO_TOKEN));

        assertEq(siloToken.balanceOf(_bob), 0);

        _mintFor();

        // 100% - 1e18
        // 10% to DAO
        uint256 expectedDAOBalance = 1e17;
        // 20$ to deployer
        uint256 expectedDeployerBalance = 2e17;
        // Bob's balance `_BOB_BALANCE` - 30% fees cut
        uint256 expectedBobBalance = 7e17;

        uint256 bobBalance = siloToken.balanceOf(_bob);
        uint256 daoBalance = siloToken.balanceOf(_daoFeeReceiver);
        uint256 deployerBalance = siloToken.balanceOf(_deployerFeeReceiver);

        assertEq(expectedBobBalance, bobBalance, "Wrong Bob's balance");
        assertEq(expectedDAOBalance, daoBalance, "Wrong DAO's balance");
        assertEq(expectedDeployerBalance, deployerBalance, "Wrong deployer's balance");
    }

    function _mintFor() internal {
        vm.warp(block.timestamp + 3_600 * 24 * 30);

        vm.prank(_bob);
        _minter.setMinterApproval(_bob, true);
        vm.prank(_bob);
        _minter.mintFor(address(_gauge), _bob);
    }

    function _mockCallsForTest() internal {
        vm.mockCall(
            _gauge,
            abi.encodeWithSelector(ISiloChildChainGauge.silo.selector),
            abi.encode(_silo)
        );

        vm.mockCall(
            _gauge,
            abi.encodeWithSelector(ISiloChildChainGauge.factory.selector),
            abi.encode(address(_liquidityGaugeFactory))
        );

        vm.mockCall(
            _gauge,
            abi.encodeWithSelector(ISiloChildChainGauge.user_checkpoint.selector, _bob),
            abi.encode(true)
        );

        vm.mockCall(
            address(_gauge),
            abi.encodeWithSelector(ISiloChildChainGauge.integrate_fraction.selector, _bob),
            abi.encode(_BOB_BALANCE)
        );

        vm.mockCall(
            address(_liquidityGaugeFactory),
            abi.encodeWithSelector(ILiquidityGaugeFactory.isGaugeFromFactory.selector, _gauge),
            abi.encode(true)
        );
    }
}
