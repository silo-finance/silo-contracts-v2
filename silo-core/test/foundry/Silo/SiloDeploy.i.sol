// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
import {SiloFixture} from "../_common/fixtures/SiloFixture.sol";

interface IHookReceiverLike {
    function shareToken() external view returns (address);
}

// FOUNDRY_PROFILE=core forge test -vv --ffi --mc SiloDeployTest
contract SiloDeployTest is IntegrationTest {
    uint256 internal constant _FORKING_BLOCK_NUMBER = 17336000;

    ISiloConfig internal _siloConfig;
    ISilo internal _silo0;
    ISilo internal _silo1;

    TokenMock internal _token0;
    TokenMock internal _token1;

    function setUp() public {
        vm.createSelectFork(getChainRpcUrl(MAINNET_ALIAS), _FORKING_BLOCK_NUMBER);

        // Mock addresses that we need for the `SiloFactoryDeploy` script
        AddrLib.setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, makeAddr("Timelock"));
        AddrLib.setAddress(VeSiloContracts.FEE_DISTRIBUTOR, makeAddr("FeeDistributor"));

        SiloFixture siloFixture = new SiloFixture();
        address t0;
        address t1;
        (_siloConfig, _silo0, _silo1, t0, t1) = siloFixture.deploy_ETH_USDC();

        _token0 = new TokenMock(vm, t0);
        _token1 = new TokenMock(vm, t1);
    }

    // FOUNDRY_PROFILE=core forge test -vv --ffi -mt test_hooks_are_initialized
    function test_hooks_are_initialized() public { // solhint-disable-line func-name-mixedcase
         _verifyHookReceiversForSilo(address(_silo0));
         _verifyHookReceiversForSilo(address(_silo1));
    }

    function _verifyHookReceiversForSilo(address _silo) internal {
        address protectedShareToken;
        address collateralShareToken;
        address debtShareToken;

        (protectedShareToken, collateralShareToken, debtShareToken) = _siloConfig.getShareTokens(_silo);

        _verifyHookReceiverForToken(protectedShareToken, "protectedShareToken");
        _verifyHookReceiverForToken(collateralShareToken, "collateralShareToken");
        _verifyHookReceiverForToken(debtShareToken, "debtShareToken");
    }

    function _verifyHookReceiverForToken(address _token, string memory _tokenName) internal {
        address hookReceiver = IShareToken(_token).hookReceiver();

        if (hookReceiver != address(0)) {
            address initializedToken = IHookReceiverLike(hookReceiver).shareToken();
            assertEq(_token, initializedToken, "Hook receiver initialized with wrong token");
            emit log_string(string(abi.encodePacked("Hook initialized for ", _tokenName)));
        }
    }
}
