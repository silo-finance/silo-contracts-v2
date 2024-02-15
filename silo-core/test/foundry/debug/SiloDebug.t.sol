// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2Config} from "silo-core/contracts/interfaces/IInterestRateModelV2Config.sol";

import {console} from "forge-std/console.sol";

interface IRMGetters {
    struct Setup {
        // ri ≥ 0 – initial value of the integrator
        int128 ri;
        // Tcrit ≥ 0 - the time during which the utilization exceeds the critical value
        int128 Tcrit;
        IInterestRateModelV2Config config;
    }

    function getSetup(address _silo) external view returns (Setup memory setup);
}

// FOUNDRY_PROFILE=core-test forge test --mc SiloDebugTest --ffi -vvv
contract SiloDebugTest is IntegrationTest {
    address constant internal _SILO_ADDR = 0x7abd3124E1e2F5f8aBF8b862d086647A5141bf4c;
    address constant internal _IRM_ADDR = 0x9d33d45AA7E1B45c65EA4b36b0c586B58a4796cE;

    IInterestRateModelV2 constant internal _IRM = IInterestRateModelV2(_IRM_ADDR);
    IRMGetters constant internal _IRM_GETTERS = IRMGetters(_IRM_ADDR);

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(ARBITRUM_ONE_ALIAS),
            154571300
        );

        vm.label(address(_IRM), "irm");
        vm.label(_SILO_ADDR, "silo");
    }

    function testIt() public view {
        // IInterestRateModelV2.ConfigWithState memory config = _IRM.getConfig(_SILO_ADDR);

        IRMGetters.Setup memory setup = _IRM_GETTERS.getSetup(_SILO_ADDR);

        console.log("ri: ", uint256(int256(setup.ri)));
        console.log("Tcrit: ", uint256(int256(setup.Tcrit)));
        console.log("config: ", address(setup.config));
    }
}
