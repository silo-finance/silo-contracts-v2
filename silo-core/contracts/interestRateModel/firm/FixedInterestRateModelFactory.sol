// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {Create2Factory} from "common/utils/Create2Factory.sol";
import {IInterestRateModel} from "../../interfaces/IInterestRateModel.sol";

import {
    IFixedInterestRateModelFactory
} from "silo-core/contracts/interestRateModel/firm/interfaces/IFixedInterestRateModelFactory.sol";

import {
    FixedInterestRateModel, IFixedInterestRateModel
} from "silo-core/contracts/interestRateModel/firm/FixedInterestRateModel.sol";

contract FixedInterestRateModelFactory is Create2Factory, IFixedInterestRateModelFactory {
    mapping(address => bool) public createdInFactory;

    function create(
        IFixedInterestRateModel.InitConfig calldata _config,
        bytes32 _externalSalt
    )
        external
        virtual
        returns (IFixedInterestRateModel irm)
    {
        irm = new FixedInterestRateModel{salt: _salt(_externalSalt)}(_config);
        createdInFactory[address(irm)] = true;
        emit NewFixedInterestRateModel(irm);
    }
}
