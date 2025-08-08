// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";
import {IERC20} from "openzeppelin5/interfaces/IERC20.sol";
import {FixedInterestRateModel} from "silo-core/contracts/interestRateModel/firm/FixedInterestRateModel.sol";
import {FixedInterestRateModelConfig} from "silo-core/contracts/interestRateModel/firm/FixedInterestRateModelConfig.sol";
import {FixedInterestRateModelFactory} from "silo-core/contracts/interestRateModel/firm/FixedInterestRateModelFactory.sol";
import {IFixedInterestRateModel} from "silo-core/contracts/interestRateModel/firm/interfaces/IFixedInterestRateModel.sol";
import {IFixedInterestRateModelConfig} from "silo-core/contracts/interestRateModel/firm/interfaces/IFixedInterestRateModelConfig.sol";

contract FixedInterestRateModelTest is Test {
    address constant FIRM_VAULT = address(111);
    IERC20 constant SHARE_TOKEN = IERC20(address(222));
    address constant SILO = address(333);

    FixedInterestRateModelFactory factory;
    IFixedInterestRateModel irm;
    IFixedInterestRateModel.Config config;

    function setUp() public {
        factory = new FixedInterestRateModelFactory();

        config = IFixedInterestRateModel.Config({
            apr: 10 ** 18 - 1,
            maturityTimestamp: block.timestamp + 20 weeks,
            firmVault: FIRM_VAULT,
            shareToken: SHARE_TOKEN,
            silo: SILO
        });

        irm = factory.create(
            config,
            bytes32(0)
        );
    }

    function test_FixedInterestRateModel_predictAddress() public {
        address predicted = factory.predictFixedInterestRateModelAddress(address(this), bytes32(0));

        irm = factory.create(
            config,
            bytes32(0)
        );

        assertEq(address(irm), predicted);
    }

    function test_FixedInterestRateModel_initialize() public {
        IFixedInterestRateModelConfig configAddress = FixedInterestRateModel(address(irm)).irmConfig();
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        irm.initialize(address(configAddress));
    }
}
