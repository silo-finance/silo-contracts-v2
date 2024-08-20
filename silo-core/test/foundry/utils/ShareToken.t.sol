// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {MessageHashUtils} from "openzeppelin5//utils/cryptography/MessageHashUtils.sol";
import {ERC20Permit} from "openzeppelin5/token/ERC20/extensions/ERC20Permit.sol";

import {SiloMathLib} from "silo-core/contracts/lib/SiloERC4626Lib.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {HookReceiverMock} from "../_mocks/HookReceiverMock.sol";
import {SiloMock} from "../_mocks/SiloMock.sol";
import {MintableToken as Token} from "../_common/MintableToken.sol";
import {SiloConfigMock} from "../_mocks/SiloConfigMock.sol";

// solhint-disable func-name-mixedcase
// FOUNDRY_PROFILE=core-test forge test -vv --mc ShareTokenTest
contract ShareTokenTest is Test {
    uint256 constant internal _DEBT_TOKE_BEFORE_ACTION = 0;
    uint256 constant internal _DEBT_TOKE_AFTER_ACTION = Hook.DEBT_TOKEN | Hook.SHARE_TOKEN_TRANSFER;

    bytes32 constant internal _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    bytes32 constant internal _TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 constant internal _HASHED_NAME = keccak256(bytes("SiloShareToken"));
    bytes32 constant internal _HASHED_VERSION = keccak256(bytes("1"));

    ShareDebtToken public sToken;
    SiloMock public silo;
    SiloConfigMock public siloConfig;
    HookReceiverMock public hookReceiverMock;
    address public owner;

    function setUp() public {
        sToken = ShareDebtToken(Clones.clone(address(new ShareDebtToken())));
        silo = new SiloMock(address(0));
        siloConfig = new SiloConfigMock(address(0));
        hookReceiverMock = new HookReceiverMock(address(0));
        owner = makeAddr("Owner");
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt test_ShareToken_decimals
    function test_ShareToken_decimals() public {
        uint8 decimals = 8;
        Token token = new Token(decimals);

        ISiloConfig.ConfigData memory configData;
        configData.token = address(token);

        silo.configMock(siloConfig.ADDRESS());
        siloConfig.getConfigMock(silo.ADDRESS(), configData);

        sToken.initialize(ISilo(silo.ADDRESS()), address(0), uint24(Hook.DEBT_TOKEN));

        assertEq(10 ** (sToken.decimals() - token.decimals()), SiloMathLib._DECIMALS_OFFSET_POW, "expect valid offset");
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt test_notRevertWhenNoHook
    function test_notRevertWhenNoHook() public {
        silo.configMock(siloConfig.ADDRESS());
        sToken.initialize(ISilo(silo.ADDRESS()), address(0), uint24(Hook.DEBT_TOKEN));

        vm.prank(silo.ADDRESS());
        sToken.mintShares(owner, owner, 1);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt test_hookCall
    function test_hookCall() public {
        address siloAddr = silo.ADDRESS();

        silo.configMock(siloConfig.ADDRESS());
        address hookAddr = hookReceiverMock.ADDRESS();

        sToken.initialize(ISilo(siloAddr), hookAddr, uint24(Hook.DEBT_TOKEN));

        vm.prank(siloAddr);
        sToken.synchronizeHooks(
            uint24(_DEBT_TOKE_BEFORE_ACTION),
            uint24(_DEBT_TOKE_AFTER_ACTION)
        );

        uint256 amount = 1;

        _afterTokenTransferMockOnMint(amount);

        vm.prank(siloAddr);
        sToken.mintShares(owner, owner, amount);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt test_descreaseAllowance
    function test_descreaseAllowance() public {
        uint256 allowance = 100e18;
        address recipient = makeAddr("Recipient");
        address siloAddr = silo.ADDRESS();

        silo.configMock(siloConfig.ADDRESS());
        siloConfig.reentrancyGuardEnteredMock(false);
        address hookAddr = hookReceiverMock.ADDRESS();
        sToken.initialize(ISilo(siloAddr), hookAddr, uint24(Hook.DEBT_TOKEN));

        vm.prank(recipient);
        sToken.increaseReceiveAllowance(owner, allowance);

        assertEq(sToken.receiveAllowance(owner, recipient), allowance, "expect valid allowance");

        // decrease in value more than allowed
        vm.prank(recipient);
        sToken.decreaseReceiveAllowance(owner, type(uint256).max);

        assertEq(sToken.receiveAllowance(owner, recipient), 0, "expect have no allowance");
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt test_shareTokenPermit
    function test_shareTokenPermit() public {
        uint256 privateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address signer = vm.addr(privateKey);
        address spender = makeAddr("Spender");
        uint256 value = 100e18;
        uint256 nonce = sToken.nonces(signer);
        uint256 deadline = block.timestamp + 1000;
        address siloAddr = silo.ADDRESS();

        silo.configMock(siloConfig.ADDRESS());
        siloConfig.reentrancyGuardEnteredMock(false);
        address hookAddr = hookReceiverMock.ADDRESS();
        sToken.initialize(ISilo(siloAddr), hookAddr, uint24(Hook.DEBT_TOKEN));

        (uint8 v, bytes32 r, bytes32 s) =
            _createPermit(signer, privateKey, spender, value, nonce, deadline, address(sToken));

        uint256 allowanceBefore = sToken.allowance(signer, spender);
        assertEq(allowanceBefore, 0, "expect no allowance");

        sToken.permit(signer, spender, value, deadline, v, r, s);

        uint256 allowanceAfter = sToken.allowance(signer, spender);
        assertEq(allowanceAfter, value, "expect valid allowance");
    }

    function _afterTokenTransferMockOnMint(uint256 _amount) internal {
        uint256 balance = sToken.balanceOf(owner);

        hookReceiverMock.afterTokenTransferMock( // solhint-disable-line func-named-parameters
                silo.ADDRESS(),
                _DEBT_TOKE_AFTER_ACTION,
                address(0), // zero address for mint
                0, // initial total supply 0
                owner,
                balance + _amount, // owner balance after
                sToken.totalSupply() + _amount, // total supply after mint
                _amount
        );
    }

    function _createPermit(
        address _signer,
        uint256 _signerPrivateKey,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _deadline,
        address _shareToken
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 structHash =
            keccak256(abi.encode(_PERMIT_TYPEHASH, _signer, _spender, _value, _nonce, _deadline));

        bytes32 domainSeparator = ERC20Permit(_shareToken).DOMAIN_SEPARATOR();
        bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);

        (v, r, s) = vm.sign(_signerPrivateKey, digest);
    }
}
