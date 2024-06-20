// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";

import {TokenTest} from "./TokenTest.t.sol";
import {MiloTokenDeploy} from "ve-silo/deploy/MiloTokenDeploy.s.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc MiloTokenTest --ffi -vvv
contract MiloTokenTest is TokenTest {
    function _deployToken() internal override {
        MiloTokenDeploy deployment = new MiloTokenDeploy();
        deployment.disableDeploymentsSync();

        _token = deployment.run();
    }

    function _network() internal override pure returns (string memory) {
        return ARBITRUM_ONE_ALIAS;
    }

    function _forkingBlockNumber() internal override pure returns (uint256) {
        return 223482770;
    }

    function _symbol() internal override pure returns (string memory) {
        return "MILO";
    }

    function _name() internal override pure returns (string memory) {
        return "Milo";
    }

    function _decimals() internal override pure returns (uint8) {
        return 18;
    }
}