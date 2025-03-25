// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Utils} from "silo-foundry-utils/lib/Utils.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";

import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";

contract ReentrancyTestState {
    address public vault;
    address public owner;
    address public market;
    address public asset;
    bool public reenter = true;

    function set(
        address _vault,
        address _owner,
        address _market,
        address _asset
    ) external {
        vault = _vault;
        owner = _owner;
        market = _market;
        asset = _asset;
    }

    function setReenter(bool _status) external {
        reenter = _status;
    } 
}

library TestStateLib {
    address internal constant _ADDRESS = address(uint160(uint256(keccak256("silo reentrancy test"))));

    function init(
        address _vault,
        address _owner,
        address _market,
        address _asset
    ) internal {
        bytes memory code = Utils.getCodeAt(_ADDRESS);

        if (code.length !=0) return;

        ReentrancyTestState state = new ReentrancyTestState();

        bytes memory deployedCode = Utils.getCodeAt(address(state));

        VmLib.vm().etch(_ADDRESS, deployedCode);

        ReentrancyTestState(_ADDRESS).set(_vault, _owner, _market, _asset);
        ReentrancyTestState(_ADDRESS).setReenter(true);
    }

    function vault() internal view returns (ISiloVault) {
        return ISiloVault(ReentrancyTestState(_ADDRESS).vault());
    }

    function owner() internal view returns (address) {
        return ReentrancyTestState(_ADDRESS).owner();
    }

    function market() internal view returns (address) {
        return ReentrancyTestState(_ADDRESS).market();
    }

    function asset() internal view returns (address) {
        return ReentrancyTestState(_ADDRESS).asset();
    }

    function reenter() internal view returns (bool) {
        return ReentrancyTestState(_ADDRESS).reenter();
    }

    function disableReentrancy() internal {
        ReentrancyTestState(_ADDRESS).setReenter(false);
    }

    function enableReentrancy() internal {
        ReentrancyTestState(_ADDRESS).setReenter(true);
    }
}
