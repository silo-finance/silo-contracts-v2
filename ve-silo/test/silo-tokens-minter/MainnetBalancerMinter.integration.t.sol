// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {MessageHashUtils} from "openzeppelin5/utils/cryptography/EIP712.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {Errors as BalancerErrors} from "balancer-labs/v2-interfaces/solidity-utils/helpers/BalancerErrors.sol";

import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {ISiloLiquidityGauge} from "ve-silo/contracts/gauges/interfaces/ISiloLiquidityGauge.sol";
import {LiquidityGaugeFactoryDeploy} from "ve-silo/deploy/LiquidityGaugeFactoryDeploy.s.sol";
import {GaugeControllerDeploy, IGaugeController} from "ve-silo/deploy/GaugeControllerDeploy.s.sol";
import {SiloGovernorDeploy} from "ve-silo/deploy/SiloGovernorDeploy.s.sol";

import {MainnetBalancerMinterDeploy, IBalancerTokenAdmin, IBalancerMinter}
    from "ve-silo/deploy/MainnetBalancerMinterDeploy.s.sol";

import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {IVeBoost} from "ve-silo/contracts/voting-escrow/interfaces/IVeBoost.sol";
import {IExtendedOwnable} from "ve-silo/contracts/access/IExtendedOwnable.sol";
import {IShareTokenLike as IShareToken} from "ve-silo/contracts/gauges/interfaces/IShareTokenLike.sol";
import {ISiloMock as ISilo} from "ve-silo/test/_mocks/ISiloMock.sol";
import {IFeesManager} from "ve-silo/contracts/silo-tokens-minter/interfaces/IFeesManager.sol";
import {FeesManagerTest} from "./FeesManager.unit.t.sol";
import {ERC20Mint as ERC20} from "ve-silo/test/_mocks/ERC20Mint.sol";
import {EOASignaturesValidator} from "ve-silo/contracts/silo-tokens-minter/helpers/EOASignaturesValidator.sol";

import {
    ISiloFactoryWithFeeDetails as ISiloFactory
} from "ve-silo/contracts/silo-tokens-minter/interfaces/ISiloFactoryWithFeeDetails.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc MainnetBalancerMinterTest --ffi -vvv
contract MainnetBalancerMinterTest is IntegrationTest {
    uint256 internal constant _WEIGHT_CAP = 1e18;
    uint256 internal constant _BOB_BALANCE = 1e18;
    uint256 internal constant _DAO_FEE = 1e3; // 10%
    uint256 internal constant _DEPLOYER_FEE = 2e3; // 20%

    bytes32 internal constant _SET_MINTER_APPROVAL_TYPEHASH =
        keccak256("SetMinterApproval(address minter,bool approval,uint256 nonce,uint256 deadline)");

    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 internal _hashedName = keccak256(bytes("Silo Minter"));
    bytes32 internal _hashedVersion = keccak256(bytes("1"));

    ILiquidityGaugeFactory internal _factory;
    ISiloLiquidityGauge internal _gauge;
    IBalancerTokenAdmin internal _balancerTokenAdmin;
    IBalancerMinter internal _minter;
    IGaugeController internal _gaugeController;
    FeesManagerTest internal _feesTest;

    address internal _hookReceiver = makeAddr("Hook receiver");
    address internal _shareToken = makeAddr("Share token");
    address internal _silo = makeAddr("Silo");
    address internal _siloFactory = makeAddr("Silo Factory");
    address internal _daoFeeReceiver = makeAddr("DAO fee receiver");
    address internal _deployerFeeReceiver = makeAddr("Deployer fee receiver");
    address internal _bob = makeAddr("Bob");
    address internal _deployer;

    event MiningProgramStoped();
    event MinterApprovalSet(address indexed user, address indexed minter, bool approval);

    // solhint-disable-next-line function-max-lines
    function setUp() public {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);

        _dummySiloToken();

        SiloGovernorDeploy _governanceDeploymentScript = new SiloGovernorDeploy();
        _governanceDeploymentScript.disableDeploymentsSync();

        LiquidityGaugeFactoryDeploy _factoryDeploy = new LiquidityGaugeFactoryDeploy();
        GaugeControllerDeploy _controllerDeploymentScript = new GaugeControllerDeploy();
        MainnetBalancerMinterDeploy _minterDeploy = new MainnetBalancerMinterDeploy();

        _governanceDeploymentScript.run();
        _gaugeController = _controllerDeploymentScript.run();
        (_minter, _balancerTokenAdmin) = _minterDeploy.run();

        vm.mockCall(
            getAddress(SILO_TOKEN),
            abi.encodeWithSelector(IExtendedOwnable.owner.selector),
            abi.encode(address(_balancerTokenAdmin))
        );

        _factory = _factoryDeploy.run();

        vm.prank(_deployer);
        _balancerTokenAdmin.activate();

        // Set manager of the `balancerTokenAdmin` a `minter` smart contract to be able to mint tokens
        vm.prank(_deployer);
        IExtendedOwnable(address(_balancerTokenAdmin)).changeManager(address(_minter));

        // mocking silo core as it is not deployed and we are testing without it
        _mockSiloCore();

        _gauge = ISiloLiquidityGauge(_factory.create(_WEIGHT_CAP, _shareToken));

        _mockCallsForTest();

        _feesTest = new FeesManagerTest();
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testSetMinterApproval --ffi -vvv
    function testSetMinterApproval() public {
        address minter = makeAddr("Minter");
        address user = makeAddr("User");
        address other = makeAddr("Other");

        vm.expectEmit(false, false, true, true);

        emit MinterApprovalSet(user, minter, true);

        vm.prank(user);
        _minter.setMinterApproval(minter, true);

        assertTrue(_minter.getMinterApproval(minter, user), "Minter should be approved");
        assertTrue(_minter.allowed_to_mint_for(minter, user), "Minter should be approved");

        assertFalse(_minter.getMinterApproval(other, user), "other acc should not be approved");
        assertFalse(_minter.allowed_to_mint_for(other, user), "other acc should not be approved");
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testRemoveMinterApproval --ffi -vvv
    function testRemoveMinterApproval() public {
        address minter = makeAddr("Minter");
        address user = makeAddr("User");

        vm.prank(user);
        _minter.setMinterApproval(minter, true);

        vm.expectEmit(false, false, true, true);

        emit MinterApprovalSet(user, minter, false);

        vm.prank(user);
        _minter.setMinterApproval(minter, false);

        assertFalse(_minter.getMinterApproval(minter, user), "Minter should not be approved");
        assertFalse(_minter.allowed_to_mint_for(minter, user), "Minter should not be approved");
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testToogleMinterApproval --ffi -vvv
    function testToogleMinterApproval() public {
        address minter = makeAddr("Minter");
        address user = makeAddr("User");

        vm.prank(user);
        _minter.setMinterApproval(minter, true);

        assertTrue(_minter.getMinterApproval(minter, user), "Minter should be approved");

        vm.expectEmit(false, false, true, true);

        emit MinterApprovalSet(user, minter, false);

        vm.prank(user);
        _minter.toggle_approve_mint(minter);

        assertFalse(_minter.getMinterApproval(minter, user), "Minter should not be approved");
        assertFalse(_minter.allowed_to_mint_for(minter, user), "Minter should not be approved");
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testMintForWhenCallerIsNotApproved --ffi -vvv
    function testMintForWhenCallerIsNotApproved() public {
        _mockFees();

        vm.warp(block.timestamp + 30 days);

        vm.expectRevert("Caller not allowed to mint for user");
        _minter.mintFor(address(_gauge), _bob);

        vm.expectRevert("Caller not allowed to mint for user");
        _minter.mintManyFor(new address[](0), _bob);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testSignatureApprovalSet --ffi -vvv
    function testSignatureApprovalSet() public {
        address minter = makeAddr("Minter");
        VmSafe.Wallet memory user = vm.createWallet("Proof signer");

        uint256 deadline = block.timestamp + 1 days;

        bytes32 structHash = _hashData(minter, user.addr, true, deadline);
        bytes32 digest = _hashTypedDataV4(structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user.privateKey, digest);

        vm.expectEmit(false, false, true, true);

        emit MinterApprovalSet(user.addr, minter, true);
        
        vm.prank(user.addr);
        _minter.setMinterApprovalWithSignature(minter, true, user.addr, deadline, v, r, s);

        assertTrue(_minter.getMinterApproval(minter, user.addr), "Minter should be approved");
        assertTrue(_minter.allowed_to_mint_for(minter, user.addr), "Minter should be approved");
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testSignatureApprovalExpired --ffi -vvv
    function testSignatureApprovalExpired() public {
        address minter = makeAddr("Minter");
        VmSafe.Wallet memory user = vm.createWallet("Proof signer");

        uint256 deadline = block.timestamp;

        bytes32 structHash = _hashData(minter, user.addr, true, deadline);
        bytes32 digest = _hashTypedDataV4(structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user.privateKey, digest);

        vm.warp(block.timestamp + 1 days);

        vm.expectRevert(_balancerError(BalancerErrors.EXPIRED_SIGNATURE));

        vm.prank(user.addr);
        _minter.setMinterApprovalWithSignature(minter, true, user.addr, deadline, v, r, s);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testSignatureApprovalInvalidSignatureOtherMinter --ffi -vvv
    function testSignatureApprovalInvalidSignatureOtherMinter() public {
        address minter = makeAddr("Minter");
        VmSafe.Wallet memory user = vm.createWallet("Proof signer");

        uint256 deadline = block.timestamp + 1 days;

        bytes32 structHash = _hashData(makeAddr("Other user"), user.addr, true, deadline);
        bytes32 digest = _hashTypedDataV4(structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user.privateKey, digest);

        vm.expectRevert(_balancerError(BalancerErrors.INVALID_SIGNATURE));

        vm.prank(user.addr);
        _minter.setMinterApprovalWithSignature(minter, true, user.addr, deadline, v, r, s);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testSignatureApprovalInvalidSignatureOtherUser --ffi -vvv
    function testSignatureApprovalInvalidSignatureOtherUser() public {
        address minter = makeAddr("Minter");
        VmSafe.Wallet memory user = vm.createWallet("Proof signer");
        VmSafe.Wallet memory other = vm.createWallet("Proof signer other");

        uint256 deadline = block.timestamp + 1 days;

        bytes32 structHash = _hashData(minter, other.addr, true, deadline);
        bytes32 digest = _hashTypedDataV4(structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(other.privateKey, digest);

        vm.expectRevert(_balancerError(BalancerErrors.INVALID_SIGNATURE));

        vm.prank(user.addr);
        _minter.setMinterApprovalWithSignature(minter, true, user.addr, deadline, v, r, s);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testSignatureApprovalInvalidSignatureOppositApproval --ffi -vvv
    function testSignatureApprovalInvalidSignatureOppositApproval() public {
        address minter = makeAddr("Minter");
        VmSafe.Wallet memory user = vm.createWallet("Proof signer");

        uint256 deadline = block.timestamp + 1 days;

        bytes32 structHash = _hashData(minter, user.addr, false, deadline);
        bytes32 digest = _hashTypedDataV4(structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user.privateKey, digest);

        vm.expectRevert(_balancerError(BalancerErrors.INVALID_SIGNATURE));

        vm.prank(user.addr);
        _minter.setMinterApprovalWithSignature(minter, true, user.addr, deadline, v, r, s);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testSignatureApprovalInvalidSignatureEmptyAddr --ffi -vvv
    function testSignatureApprovalInvalidSignatureEmptyAddr() public {
        address minter = makeAddr("Minter");
        VmSafe.Wallet memory user = vm.createWallet("Proof signer");

        uint256 deadline = block.timestamp + 1 days;

        bytes32 structHash = _hashData(minter, user.addr, false, deadline);
        bytes32 digest = _hashTypedDataV4(structHash);

        (uint8 v,, bytes32 s) = vm.sign(user.privateKey, digest);

        bytes32 r = 0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef;

        vm.expectRevert(_balancerError(BalancerErrors.INVALID_SIGNATURE));

        vm.prank(user.addr);
        _minter.setMinterApprovalWithSignature(minter, true, user.addr, deadline, v, r, s);
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

    /// @notice Should mint tokens
    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testMintForNoFees --ffi -vvv
    function testMintForNoFees() public {
        // without fees
        vm.mockCall(
            _siloFactory,
            abi.encodeWithSelector(ISiloFactory.getFeeReceivers.selector, _silo),
            abi.encode(
                address(0),
                address(0)
            )
        );

        IERC20 siloToken = IERC20(getAddress(SILO_TOKEN));

        assertEq(siloToken.balanceOf(_bob), 0);
        assertEq(_minter.minted(_bob, address(_gauge)), 0);

        _mintFor();

        assertEq(siloToken.balanceOf(_bob), _BOB_BALANCE);
        assertEq(_minter.minted(_bob, address(_gauge)), _BOB_BALANCE);
    }

    /// @notice Should mint tokens and collect fees
    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testMintForWithFees --ffi -vvv
    function testMintForWithFees() public {
        // with fees
        // 10% - to DAO
        // 20% - to deployer
        vm.mockCall(
            _siloFactory,
            abi.encodeWithSelector(ISiloFactory.getFeeReceivers.selector, _silo),
            abi.encode(
                _daoFeeReceiver,
                _deployerFeeReceiver
            )
        );

        vm.prank(_deployer);
        IFeesManager(address(_minter)).setFees(_DAO_FEE, _DEPLOYER_FEE);

        IERC20 siloToken = IERC20(getAddress(SILO_TOKEN));

        assertEq(siloToken.balanceOf(_bob), 0);
        assertEq(_minter.minted(_bob, address(_gauge)), 0);

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
        assertEq(_minter.minted(_bob, address(_gauge)), _BOB_BALANCE);
    }

    function testStopMining() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _balancerTokenAdmin.stopMining();

        vm.mockCall(
            getAddress(SILO_TOKEN),
            abi.encodeWithSelector(Ownable.transferOwnership.selector, _deployer),
            abi.encode(true)
        );

        vm.expectEmit(false, false, false, false);
        emit MiningProgramStoped();

        vm.prank(_deployer);
        _balancerTokenAdmin.stopMining();
    }

    function _mintFor() internal {
        vm.warp(block.timestamp + 3_600 * 24 * 30);

        vm.prank(_bob);
        _minter.setMinterApproval(_bob, true);
        vm.prank(_bob);
        _minter.mintFor(address(_gauge), _bob);
    }

    function _dummySiloToken() internal {
        if (isChain(ANVIL_ALIAS)) {
            ERC20 siloToken = new ERC20("Silo test token", "SILO");

            setAddress(getChainId(), SILO_TOKEN, address(siloToken));
        }
    }

    function _mockCallsForTest() internal {
        vm.mockCall(
            address(_gaugeController),
            abi.encodeWithSelector(IGaugeController.gauge_types.selector, address(_gauge)),
            abi.encode(1)
        );

        vm.mockCall(
            address(_gauge),
            abi.encodeWithSelector(ISiloLiquidityGauge.user_checkpoint.selector, address(_bob)),
            abi.encode(true)
        );

        vm.mockCall(
            address(_gauge),
            abi.encodeWithSelector(ISiloLiquidityGauge.integrate_fraction.selector, address(_bob)),
            abi.encode(_BOB_BALANCE)
        );
    }

    function _mockSiloCore() internal {
        vm.mockCall(
            _shareToken,
            abi.encodeWithSelector(IShareToken.hookReceiver.selector),
            abi.encode(_hookReceiver)
        );

        vm.mockCall(
            _shareToken,
            abi.encodeWithSelector(IShareToken.silo.selector),
            abi.encode(_silo)
        );

        vm.mockCall(
            _silo,
            abi.encodeWithSelector(ISilo.factory.selector),
            abi.encode(_siloFactory)
        );
    }

    function _mockFees() internal {
        // without fees
        vm.mockCall(
            _siloFactory,
            abi.encodeWithSelector(ISiloFactory.getFeeReceivers.selector, _silo),
            abi.encode(
                address(0),
                address(0)
            )
        );
    }

    function _buildDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(_minter)));
    }

    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_buildDomainSeparator(), structHash);
    }

    function _hashData(
        address userMinter,
        address user,
        bool approval,
        uint256 deadline
    ) internal view returns (bytes32 structHash) {
        uint256 userNonce = EOASignaturesValidator(address(_minter)).getNextNonce(user);

        structHash = keccak256(
            abi.encode(_SET_MINTER_APPROVAL_TYPEHASH, userMinter, approval, userNonce, deadline)
        );
    }

    function _balancerError(uint256 _errorCode) internal pure returns (bytes memory errorMessage) {
        errorMessage = bytes(string.concat("BAL#", vm.toString(_errorCode)));
    }
}
