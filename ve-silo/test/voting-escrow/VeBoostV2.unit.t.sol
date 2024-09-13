// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {VmSafe} from "forge-std/Vm.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {VeBoostDeploy} from "ve-silo/deploy/VeBoostDeploy.s.sol";
import {IVeBoost} from "ve-silo/contracts/voting-escrow/interfaces/IVeBoost.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc VeBoostV2Test --ffi -vvv
contract VeBoostV2Test is IntegrationTest {
    string constant internal _NAME = "Vote-Escrowed Boost";
    string constant internal _SYMBOL = "veBoost";
    string constant internal _VERSION = "v2.0.0";

    bytes32 constant internal _EIP712_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 constant internal PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    uint256 value = 50000e18;
    uint256 deadline = block.timestamp + 1 days;

    address internal _veSilo = makeAddr("VeSiloMock");
    VmSafe.Wallet internal _holder = vm.createWallet("Holder (proof signer)");
    address internal _spender = makeAddr("Spender");
    IVeBoost internal _veBoost;

    function setUp() public {
        AddrLib.setAddress(VeSiloContracts.VOTING_ESCROW, _veSilo);

        VeBoostDeploy deploy = new VeBoostDeploy();
        deploy.disableDeploymentsSync();

        _veBoost = IVeBoost(address(deploy.run()));
    }

    function testProperSetup() public view {
        assertEq(_veBoost.name(), _NAME, "Invalid name");
        assertEq(_veBoost.symbol(), _SYMBOL, "Invalid symbol");
        assertEq(_veBoost.version(), _VERSION, "Invalid version");

        // initial nonce is zero
        assertEq(_veBoost.nonces(_holder.addr), 0, "Invalid initial nonce");
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testVeBoostAcceptHolderSignature --ffi -vvv
    function testVeBoostAcceptHolderSignature() public {
        uint256 nonce = _veBoost.nonces(_holder.addr);

        bytes32 digest = _digest(_holder.addr, _spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_holder.privateKey, digest);

        _veBoost.permit(_holder.addr, _spender, value, deadline, v, r, s);
        
        assertEq(_veBoost.nonces(_holder.addr), nonce + 1, "Invalid nonce");
        assertEq(_veBoost.allowance(_holder.addr, _spender), value, "Invalid allowance balance");
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testVeBoostReuseSignature --ffi -vvv
    function testVeBoostReuseSignature() public {
        uint256 nonce = _veBoost.nonces(_holder.addr);

        bytes32 digest = _digest(_holder.addr, _spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_holder.privateKey, digest);

        _veBoost.permit(_holder.addr, _spender, value, deadline, v, r, s);
        
        assertEq(_veBoost.nonces(_holder.addr), nonce + 1, "Invalid nonce");
        assertEq(_veBoost.allowance(_holder.addr, _spender), value, "Invalid allowance balance");

        vm.expectRevert("INVALID_SIGNATURE");
        _veBoost.permit(_holder.addr, _spender, value, deadline, v, r, s);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testVeBoostSignatureForOtherHolder --ffi -vvv
    function testVeBoostSignatureForOtherHolder() public {
        uint256 nonce = _veBoost.nonces(_holder.addr);

        bytes32 digest = _digest(_holder.addr, _holder.addr, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_holder.privateKey, digest);

        vm.expectRevert("INVALID_SIGNATURE");
        _veBoost.permit(_holder.addr, _spender, value, deadline, v, r, s);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testVeBoostSignatureForOtherSpender --ffi -vvv
    function testVeBoostSignatureForOtherSpender() public {
        uint256 nonce = _veBoost.nonces(_holder.addr);

        bytes32 digest = _digest(_spender, _spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_holder.privateKey, digest);

        vm.expectRevert("INVALID_SIGNATURE");
        _veBoost.permit(_holder.addr, _spender, value, deadline, v, r, s);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testVeBoostSignatureForOtherAmount --ffi -vvv
    function testVeBoostSignatureForOtherAmount() public {
        uint256 nonce = _veBoost.nonces(_holder.addr);

        bytes32 digest = _digest(_holder.addr, _spender, value + 1, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_holder.privateKey, digest);

        vm.expectRevert("INVALID_SIGNATURE");
        _veBoost.permit(_holder.addr, _spender, value, deadline, v, r, s);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testVeBoostSignatureForOtherToken --ffi -vvv
    function testVeBoostSignatureForOtherToken() public {
        uint256 nonce = _veBoost.nonces(_holder.addr);

        bytes32 invalidDomainSeparator = keccak256(abi.encode(
            _EIP712_TYPEHASH,
            keccak256(bytes(_NAME)),
            keccak256(bytes(_VERSION)),
            block.chainid,
            address(this)
        ));

        bytes32 invalidDigest = keccak256(abi.encode(
            invalidDomainSeparator,
            keccak256(abi.encode(
                PERMIT_TYPEHASH,
                _holder.addr,
                _spender,
                value,
                nonce,
                deadline
            ))
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_holder.privateKey, invalidDigest);

        vm.expectRevert("INVALID_SIGNATURE");
        _veBoost.permit(_holder.addr, _spender, value, deadline, v, r, s);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testVeBoostSignatureInvalidNonce --ffi -vvv
    function testVeBoostSignatureInvalidNonce() public {
        uint256 nonce = _veBoost.nonces(_holder.addr) + 1;

        bytes32 digest = _digest(_holder.addr, _spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_holder.privateKey, digest);

        vm.expectRevert("INVALID_SIGNATURE");
        _veBoost.permit(_holder.addr, _spender, value, deadline, v, r, s);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testVeBoostSignatureExpiredDeadline --ffi -vvv
    function testVeBoostSignatureExpiredDeadline() public {
        uint256 nonce = _veBoost.nonces(_holder.addr);
        uint256 expiredDeadline = block.timestamp - 1;

        bytes32 digest = _digest(_holder.addr, _spender, value, nonce, expiredDeadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_holder.privateKey, digest);

        vm.expectRevert("EXPIRED_SIGNATURE");
        _veBoost.permit(_holder.addr, _spender, value, expiredDeadline, v, r, s);
    }

    function _digest(
        address _owner,
        address _spenderAddr,
        uint256 _value,
        uint256 _nonce,
        uint256 _deadline
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            _domainSeparatorV4(),
            keccak256(abi.encode(
                PERMIT_TYPEHASH,
                _owner,
                _spenderAddr,
                _value,
                _nonce,
                _deadline
            ))
        ));
    }

    function _domainSeparatorV4() internal view returns (bytes32) {
        return keccak256(abi.encode(
            _EIP712_TYPEHASH,
            keccak256(bytes(_NAME)),
            keccak256(bytes(_VERSION)),
            block.chainid,
            address(_veBoost)
        ));
    }
}
