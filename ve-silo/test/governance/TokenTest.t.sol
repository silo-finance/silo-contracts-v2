// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {MessageHashUtils} from "openzeppelin5//utils/cryptography/MessageHashUtils.sol";
import {ERC20Permit} from "openzeppelin5/token/ERC20/extensions/ERC20Permit.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ISiloToken} from "ve-silo/contracts/governance/interfaces/ISiloToken.sol";
import {MiloTokenDeploy} from "ve-silo/deploy/MiloTokenDeploy.s.sol";
import {BalancerTokenAdmin} from "ve-silo/contracts/silo-tokens-minter/BalancerTokenAdmin.sol";
import {IBalancerToken} from "ve-silo/contracts/silo-tokens-minter/BalancerTokenAdmin.sol";

abstract contract TokenTest is IntegrationTest {
    bytes32 constant internal _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    bytes32 constant internal _TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 constant internal _HASHED_VERSION = keccak256(bytes("1"));

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

    function testTokenPermit() public {
        VmSafe.Wallet memory signer = vm.createWallet("Proof signer");

        address spender = makeAddr("Spender");
        uint256 value = 100e18;
        uint256 nonce = _token.nonces(signer.addr);
        uint256 deadline = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) =
            _createPermit(signer, spender, value, nonce, deadline, address(_token));

        uint256 allowanceBefore = _token.allowance(signer.addr, spender);
        assertEq(allowanceBefore, 0, "expect no allowance");

        _token.permit(signer.addr, spender, value, deadline, v, r, s);

        uint256 allowanceAfter = _token.allowance(signer.addr, spender);
        assertEq(allowanceAfter, value, "expect valid allowance");
    }

    function testCanInitializeAndStopTokenAdmin() public {
        vm.prank(_deployer);
        BalancerTokenAdmin balancerTokenAdmin = new BalancerTokenAdmin(IBalancerToken(address(_token)));

        address owner = _token.owner();

        vm.prank(owner);
        _token.transferOwnership(address(balancerTokenAdmin));

        vm.prank(_deployer);
        balancerTokenAdmin.activate();

        assertTrue(balancerTokenAdmin.isActive(), "Failed to activate a token admin");

        vm.prank(_deployer);
        balancerTokenAdmin.stopMining();

        assertFalse(balancerTokenAdmin.isActive(), "Expect to be not active");

        address newTokenOwner = _token.owner();

        assertEq(newTokenOwner, _deployer, "Failed to transfer ownership");
    }

    function _deployToken() internal virtual {}

    function _createPermit(
        VmSafe.Wallet memory _signer,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _deadline,
        address _shareToken
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 structHash =
            keccak256(abi.encode(_PERMIT_TYPEHASH, _signer.addr, _spender, _value, _nonce, _deadline));

        bytes32 domainSeparator = ERC20Permit(_shareToken).DOMAIN_SEPARATOR();
        bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);

        (v, r, s) = vm.sign(_signer.privateKey, digest);
    }

    function _hashedName() internal pure returns (bytes32) {
        return keccak256(bytes(_name()));
    }

    function _network() internal virtual pure returns (string memory) {}
    function _forkingBlockNumber() internal virtual pure returns (uint256) {}
    function _symbol() internal virtual pure returns (string memory) {}
    function _name() internal virtual pure returns (string memory) {}
    function _decimals() internal virtual pure returns (uint8) {}
}
