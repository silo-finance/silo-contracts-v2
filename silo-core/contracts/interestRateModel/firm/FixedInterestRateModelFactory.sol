// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {Create2Factory} from "common/utils/Create2Factory.sol";
import {IInterestRateModel} from "../../interfaces/IInterestRateModel.sol";

import {
    IFixedInterestRateModelFactory
} from "silo-core/contracts/interestRateModel/firm/interfaces/IFixedInterestRateModelFactory.sol";

import {
    FixedInterestRateModel, IFixedInterestRateModel
} from "silo-core/contracts/interestRateModel/firm/FixedInterestRateModel.sol";

import {
    FixedInterestRateModelConfig
} from "silo-core/contracts/interestRateModel/firm/FixedInterestRateModelConfig.sol";

contract FixedInterestRateModelFactory is Create2Factory, IFixedInterestRateModelFactory {
    /// @dev IRM contract implementation address to clone
    FixedInterestRateModel public immutable IRM_IMPLEMENTATION; // solhint-disable-line var-name-mixedcase

    mapping(address => bool) public createdInFactory;

    constructor() {
        IRM_IMPLEMENTATION = new FixedInterestRateModel();
    }

    function create(
        IFixedInterestRateModel.Config calldata _config,
        bytes32 _externalSalt
    )
        external
        virtual
        returns (IFixedInterestRateModel irm)
    {
        bytes32 salt = _salt(_externalSalt);
        address configContract = address(new FixedInterestRateModelConfig{salt: salt}(_config));
        irm = IFixedInterestRateModel(Clones.cloneDeterministic(address(IRM_IMPLEMENTATION), salt));
        irm.initialize(configContract);
        createdInFactory[address(irm)] = true;

        emit NewFixedInterestRateModel(irm);
    }
}
