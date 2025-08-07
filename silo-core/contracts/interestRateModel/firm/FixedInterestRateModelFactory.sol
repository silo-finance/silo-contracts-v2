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

contract FixedInterestRateModelFactory is Create2Factory, IFixedInterestRateModelFactory {
    /// @dev IRM contract implementation address to clone
    FixedInterestRateModel public immutable IRM_IMPLEMENTATION; // solhint-disable-line var-name-mixedcase

    constructor() {
        IRM_IMPLEMENTATION = new FixedInterestRateModel();
    }

    function create(IFixedInterestRateModel.Config calldata _config, bytes32 _externalSalt)
        external
        virtual
        returns (bytes32 configHash, IFixedInterestRateModel irm)
    {
        configHash = hashConfig(_config);

        irm = irmByConfigHash[configHash];

        if (address(irm) != address(0)) {
            return (configHash, irm);
        }

        verifyConfig(_config);

        bytes32 salt = _salt(_externalSalt);

        address configContract = address(new InterestRateModelV2Config{salt: salt}(_config));

        irm = IInterestRateModelV2(Clones.cloneDeterministic(IRM, salt));
        IInterestRateModel(address(irm)).initialize(configContract);

        irmByConfigHash[configHash] = irm;

        emit NewInterestRateModelV2(configHash, irm);
    }

    function verifyConfig(IFixedInterestRateModel.Config calldata _config) public view virtual {
        require(true);
    }
}
