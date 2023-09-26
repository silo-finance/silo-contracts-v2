// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {CommonDeploy} from "../_CommonDeploy.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

contract SiloConfigData is Test, CommonDeploy {
    // must be in alphabetic order
    struct ConfigData {
        bool borrowable0;
        bool borrowable1;
        address collateralHookReceiver0;
        address collateralHookReceiver1;
        address debtHookReceiver0;
        address debtHookReceiver1;
        address deployer;
        uint256 deployerFeeInBp;
        uint64 flashloanFee0;
        uint64 flashloanFee1;
        address interestRateModel0;
        address interestRateModel1;
        string interestRateModelConfig0;
        string interestRateModelConfig1;
        uint64 liquidationFee0;
        uint64 liquidationFee1;
        uint64 lt0;
        uint64 lt1;
        uint64 maxLtv0;
        uint64 maxLtv1;
        address maxLtvOracle0;
        address maxLtvOracle1;
        address protectedHookReceiver0;
        address protectedHookReceiver1;
        address solvencyOracle0;
        address solvencyOracle1;
        string token0;
        string token1;
    }

    function _readInput(string memory _input) internal view returns (string memory) {
        string memory inputDir = string.concat(vm.projectRoot(), "/silo-core/deploy/input/");
        string memory chainDir = string.concat(vm.toString(block.chainid), "/");
        string memory file = string.concat(_input, ".json");
        return vm.readFile(string.concat(inputDir, chainDir, file));
    }

    function _readDataFromJson(string memory _name) internal view returns (ConfigData memory) {
        return abi.decode(vm.parseJson(_readInput(_name), string(abi.encodePacked("."))), (ConfigData));
    }

    function getConfigData(string memory _name)
        public
        view
        returns (ConfigData memory config, ISiloConfig.InitData memory initData)
    {
        config = _readDataFromJson(_name);
        initData = ISiloConfig.InitData({
            deployer: config.deployer,
            deployerFeeInBp: config.deployerFeeInBp,
            token0: getAddress(config.token0),
            solvencyOracle0: address(0),
            maxLtvOracle0: address(0),
            interestRateModel0: address(0),
            interestRateModelConfig0: address(0),
            maxLtv0: config.maxLtv0,
            lt0: config.lt0,
            liquidationFee0: config.liquidationFee0,
            flashloanFee0: config.flashloanFee0,
            borrowable0: config.borrowable0,
            protectedHookReceiver0: address(0),
            collateralHookReceiver0: address(0),
            debtHookReceiver0: address(0),
            token1: getAddress(config.token1),
            solvencyOracle1: address(0),
            maxLtvOracle1: address(0),
            interestRateModel1: address(0),
            interestRateModelConfig1: address(0),
            maxLtv1: config.maxLtv1,
            lt1: config.lt1,
            liquidationFee1: config.liquidationFee1,
            flashloanFee1: config.flashloanFee1,
            borrowable1: config.borrowable1,
            protectedHookReceiver1: address(0),
            collateralHookReceiver1: address(0),
            debtHookReceiver1: address(0)
        });
    }

    // TODO
    // function print(ISiloConfig.InitData memory _initData) public {
    //     emit log_named_uint("deployer", _configData.uopt);
    // }
}
