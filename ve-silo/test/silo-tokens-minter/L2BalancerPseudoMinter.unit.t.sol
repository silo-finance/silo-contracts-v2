// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {ISiloChildChainGauge} from "ve-silo/contracts/gauges/interfaces/ISiloChildChainGauge.sol";
import {ISiloMock as ISilo} from "ve-silo/test/_mocks/ISiloMock.sol";
import {IFeesManager} from "ve-silo/contracts/silo-tokens-minter/interfaces/IFeesManager.sol";
import {FeesManagerTest} from "./FeesManager.unit.t.sol";
import {ERC20Mint} from "ve-silo/test/_mocks/ERC20Mint.sol";

import {
    ISiloFactoryWithFeeDetails as ISiloFactory
} from "ve-silo/contracts/silo-tokens-minter/interfaces/ISiloFactoryWithFeeDetails.sol";

import {
    L2BalancerPseudoMinterDeploy,
    IL2BalancerPseudoMinter
} from "ve-silo/deploy/L2BalancerPseudoMinterDeploy.s.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc L2BalancerPseudoMinterTest --ffi -vvv
contract L2BalancerPseudoMinterTest is IntegrationTest {
    uint256 internal constant _BOB_BALANCE = 1e18;
    uint256 internal constant _DAO_FEE = 1e3; // 10%
    uint256 internal constant _DEPLOYER_FEE = 2e3; // 20%

    FeesManagerTest internal _feesTest;
    ERC20Mint internal _siloToken;
    IL2BalancerPseudoMinter internal _minter;
    ILiquidityGaugeFactory internal _liquidityGaugeFactory =
        ILiquidityGaugeFactory(makeAddr("Liquidity gauge factory"));

    address internal _gauge = makeAddr("Gauge");
    address internal _bob = makeAddr("Bob");
    address internal _hookReceiver = makeAddr("Hook receiver");
    address internal _shareToken = makeAddr("Share token");
    address internal _silo = makeAddr("Silo");
    address internal _siloFactory = makeAddr("Silo Factory");
    address internal _daoFeeReceiver = makeAddr("DAO fee receiver");
    address internal _deployerFeeReceiver = makeAddr("Deployer fee receiver");
    address internal _deployer;

    function setUp() public {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);

        L2BalancerPseudoMinterDeploy deploy = new L2BalancerPseudoMinterDeploy();
        deploy.disableDeploymentsSync();

        _siloToken = new ERC20Mint("Test", "T");

        setAddress(SILO_TOKEN, address(_siloToken));

        _minter = deploy.run();

        _mockCallsForTest();

        _siloToken.mint(address(_minter), _BOB_BALANCE);

        _feesTest = new FeesManagerTest();
    }

    function testOnlyOwnerCanSetFees() public {
        _feesTest.onlyOwnerCanSetFees(
            IFeesManager(address(_minter)),
            _DAO_FEE,
            _DEPLOYER_FEE,
            _deployer
        );
    }

    function testMaxFees() public {
        _feesTest.onlyOwnerCanSetFees(
            IFeesManager(address(_minter)),
            _DAO_FEE,
            _DEPLOYER_FEE + 1,
            _deployer
        );
    }

    function testAddGaugeFactoryPermissions() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _minter.addGaugeFactory(_liquidityGaugeFactory);

        vm.prank(_deployer);
        _minter.addGaugeFactory(_liquidityGaugeFactory);

        assertTrue(_minter.isValidGaugeFactory(_liquidityGaugeFactory), "Failed to add a factory");
    }

    function testRemoveGaugeFactoryPermissions() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
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
            _gauge,
            abi.encodeWithSelector(ISiloChildChainGauge.getFeeReceivers.selector),
            abi.encode(
                address(0),
                address(0)
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
            _gauge,
            abi.encodeWithSelector(ISiloChildChainGauge.getFeeReceivers.selector),
            abi.encode(
                _daoFeeReceiver,
                _deployerFeeReceiver
            )
        );

        vm.prank(_deployer);
        IFeesManager(address(_minter)).setFees(_DAO_FEE, _DEPLOYER_FEE);

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
