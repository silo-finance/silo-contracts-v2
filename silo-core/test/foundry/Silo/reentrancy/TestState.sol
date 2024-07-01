// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Utils} from "silo-foundry-utils/lib/Utils.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

contract ReentracyTestState {
    address public siloConfig;
    address public silo0;
    address public silo1;
    address public token0;
    address public token1;
    bool public reenter = true;

    function set(
        address _siloConfig,
        address _silo0,
        address _silo1,
        address _token0,
        address _token1
    ) external {
        siloConfig = _siloConfig;
        silo0 = _silo0;
        silo1 = _silo1;
        token0 = _token0;
        token1 = _token1;
    }

    function setReenter(bool _status) external {
        reenter = _status;
    } 
}

library TestStateLib {
    address internal constant _ADDRESS = address(uint160(uint256(keccak256("silo reentrancy test"))));

    function init(
        address _siloConfig,
        address _silo0,
        address _silo1,
        address _token0,
        address _token1
    ) internal {
        bytes memory code = Utils.getCodeAt(_ADDRESS);

        if (code.length !=0) return;

        ReentracyTestState state = new ReentracyTestState();

        bytes memory deployedCode = Utils.getCodeAt(address(state));

        VmLib.vm().etch(_ADDRESS, deployedCode);

        ReentracyTestState(_ADDRESS).set(_siloConfig, _silo0, _silo1, _token0, _token1);
        ReentracyTestState(_ADDRESS).setReenter(true);
    }

    function silo0() internal view returns (ISilo) {
        return ISilo(ReentracyTestState(_ADDRESS).silo0());
    }

    function silo1() internal view returns (ISilo) {
        return ISilo(ReentracyTestState(_ADDRESS).silo1());
    }

    function token0() internal view returns (address) {
        return ReentracyTestState(_ADDRESS).token0();
    }

    function token1() internal view returns (address) {
        return ReentracyTestState(_ADDRESS).token1();
    }

    function siloConfig() internal view returns (ISiloConfig) {
        return ISiloConfig(ReentracyTestState(_ADDRESS).siloConfig());
    }

    function reenter() internal view returns (bool) {
        return ReentracyTestState(_ADDRESS).reenter();
    }

    function disableReentrancy() internal {
        ReentracyTestState(_ADDRESS).setReenter(false);
    }

    function enableReentrancy() internal {
        ReentracyTestState(_ADDRESS).setReenter(true);
    }
}
