// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

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

    address internal _veSilo = makeAddr("VeSiloMock");
    address internal _holder = makeAddr("Holder");
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
        assertEq(_veBoost.nonces(_holder), 0, "Invalid initial nonce");
    }

    function testAcceptHolderSignature() public {

    }
}
