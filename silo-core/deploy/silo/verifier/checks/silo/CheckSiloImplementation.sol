// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICheck} from "silo-core/deploy/silo/verifier/checks/ICheck.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {Test} from "forge-std/Test.sol";

contract CheckSiloImplementation is ICheck, Test {
    ISiloConfig.ConfigData internal configData;
    string internal siloName;

    constructor(ISiloConfig.ConfigData memory _configData, bool _isSiloZero) {
        configData = _configData;
        siloName = _isSiloZero ? "silo0" : "silo1";
    }

    function checkName() external view override returns (string memory name) {
        name = string.concat(siloName, " Silo implementation is known");
    }

    function successMessage() external pure override returns (string memory message) {
        message = "Silo implementation is our deployment";
    }

    function errorMessage() external pure override returns (string memory message) {
        message = "Silo implementation is NOT our deployment";
    }

    function execute() external view override returns (bool result) {
        result = _verifySiloImplementation(configData.silo);
    }

    function _verifySiloImplementation(address _silo) internal view returns (bool success) {
        bytes memory bytecode = address(_silo).code;

        if (bytecode.length != 45) {
            return false;
        }

        uint256 offset = 10;
        uint256 length = 20;

        bytes memory implBytes = new bytes(length);

        for (uint256 i = offset; i < offset + length; i++) {
            implBytes[i - offset] = bytecode[i];
        }

        address impl = address(bytes20(implBytes));

        bool isOurImplementation = false;

        string memory root = vm.projectRoot();
        string memory abiPath = string.concat(root, "/silo-core/deploy/silo/_siloImplementations.json");
        string memory json = vm.readFile(abiPath);

        string memory chainAlias = ChainsLib.chainAlias();

        bytes memory chainData = vm.parseJson(json, string(abi.encodePacked(".", chainAlias)));

        for (uint256 i = 0; i < chainData.length; i++) {
            bytes memory implementationData = vm.parseJson(
                json,
                string(abi.encodePacked(".", chainAlias, "[", vm.toString(i), "].implementation"))
            );

            address implementationAddress = abi.decode(implementationData, (address));

            if (impl == implementationAddress) {
                isOurImplementation = true;
                return true;
            }
        }

        return false;
    }
}
