// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";

import {Create2Factory} from "common/utils/Create2Factory.sol";

import {IInterestRateModel} from "../../interfaces/IInterestRateModel.sol";
import {IDynamicKinkModel} from "../../interfaces/IDynamicKinkModel.sol";
import {IDynamicKinkModelFactory} from "../../interfaces/IDynamicKinkModelFactory.sol";

import {DynamicKinkModel} from "./DynamicKinkModel.sol";
import {DynamicKinkModelConfig} from "./DynamicKinkModelConfig.sol";
import {KinkMath} from "../../lib/KinkMath.sol";

/// @title DynamicKinkModelFactory
/// @dev It creates DynamicKinkModelConfig.
contract DynamicKinkModelFactory is Create2Factory, IDynamicKinkModelFactory {
    using KinkMath for int256;

    /// @dev DP in 18 decimal points used for integer calculations
    int256 public constant DP = int256(1e18);

    /// @dev IRM contract implementation address to clone
    DynamicKinkModel public immutable IRM;

    constructor() {
        IRM = new DynamicKinkModel();
    }

    /// @inheritdoc IDynamicKinkModelFactory
    function create(IDynamicKinkModel.Config calldata _config, address _initialOwner, address _silo)
        external
        virtual
        returns (IInterestRateModel irm)
    {
        return _create(_config, _initialOwner, _silo, _salt());
    }

    /// @inheritdoc IDynamicKinkModelFactory
    // solhint-disable-next-line code-complexity, function-max-lines
    function generateConfig(IDynamicKinkModel.UserFriendlyConfig calldata _default)
        external
        view
        virtual
        returns (IDynamicKinkModel.Config memory config)
    {
        IDynamicKinkModel.UserFriendlyConfigInt memory defaultInt = _copyDefaultConfig(_default);

        // 0 <= ulow <= u1 <= u2 <= ucrit <= DP
        require(defaultInt.ulow.isBetween(0, defaultInt.u1), IDynamicKinkModel.InvalidUlow());
        require(defaultInt.u1.isBetween(defaultInt.ulow, defaultInt.u2), IDynamicKinkModel.InvalidU1());
        require(defaultInt.u2.isBetween(defaultInt.u1, defaultInt.ucrit), IDynamicKinkModel.InvalidU2());
        require(defaultInt.ucrit.isBetween(defaultInt.u2, DP), IDynamicKinkModel.InvalidUcrit());

        require(defaultInt.rmin >= 0, IDynamicKinkModel.InvalidRmin());
        require(defaultInt.rcritMin > defaultInt.rmin, IDynamicKinkModel.InvalidRcritMin());

        require(
            defaultInt.rcritMax.isBetween(defaultInt.rcritMin, defaultInt.r100),
            IDynamicKinkModel.InvalidRcritMax()
        );

        int256 rCheckHi = (defaultInt.r100 - defaultInt.rcritMin) / (defaultInt.rcritMax - defaultInt.rcritMin);
        int256 rCheckLo = (DP - defaultInt.ucrit) / (defaultInt.ucrit - defaultInt.ulow);
        require(rCheckHi >= rCheckLo, IDynamicKinkModel.InvalidDefaultConfig());

        int256 s = 365 days;

        require(defaultInt.tMin > 0, IDynamicKinkModel.InvalidTMin());
        require(defaultInt.tPlus >= defaultInt.tMin, IDynamicKinkModel.InvalidTPlus());
        require(defaultInt.t2.isBetween(defaultInt.tPlus, 100 * s), IDynamicKinkModel.InvalidT2());

        require(defaultInt.tMinus > 0, IDynamicKinkModel.InvalidTMinus());
        require(defaultInt.t1.isBetween(defaultInt.tMinus, 100 * s), IDynamicKinkModel.InvalidT1());

        config.rmin = defaultInt.rmin / s;
        config.kmin = (defaultInt.rcritMin - defaultInt.rmin) / (defaultInt.ucrit - defaultInt.ulow) / s;
        config.kmax = (defaultInt.rcritMax - defaultInt.rmin) / (defaultInt.ucrit - defaultInt.ulow) / s;

        config.alpha = (defaultInt.r100 - defaultInt.rmin - s * config.kmax * (DP - defaultInt.ulow))
            / (s * config.kmax * (DP - defaultInt.ucrit));

        config.c1 = (config.kmax - config.kmin) / defaultInt.t1;
        config.c2 = (config.kmax - config.kmin) / defaultInt.t2;
        
        config.cminus = ((config.kmax - config.kmin) / defaultInt.tMinus - config.c1)
            / (defaultInt.u1 - defaultInt.ulow);
        
        config.cplus = ((config.kmax - config.kmin) / defaultInt.tPlus - config.c2)
            / (defaultInt.ucrit - defaultInt.u2);
        
        config.dmax = (config.kmax - config.kmin) / defaultInt.tMin;

        IDynamicKinkModel(address(IRM)).verifyConfig(config);
    }

    /// @inheritdoc IDynamicKinkModelFactory
    function verifyConfig(IDynamicKinkModel.Config calldata _config) external view virtual {
        IRM.verifyConfig(_config);
    }

    function _create(
        IDynamicKinkModel.Config memory _config,
        address _initialOwner,
        address _silo,
        bytes32 _externalSalt
    )
        internal
        virtual
        returns (IInterestRateModel irm)
    {
        IRM.verifyConfig(_config);

        bytes32 salt = _salt(_externalSalt);

        irm = IInterestRateModel(Clones.cloneDeterministic(address(IRM), salt));
        IDynamicKinkModel(address(irm)).initialize(_config, _initialOwner, _silo);

        emit NewDynamicKinkModel(IDynamicKinkModel(address(irm)));
    }

    function _copyDefaultConfig(IDynamicKinkModel.UserFriendlyConfig calldata _default)
        internal
        pure
        returns (IDynamicKinkModel.UserFriendlyConfigInt memory config)
    {
        config.ulow = SafeCast.toInt256(_default.ulow);
        config.u1 = SafeCast.toInt256(_default.u1);
        config.u2 = SafeCast.toInt256(_default.u2);
        config.ucrit = SafeCast.toInt256(_default.ucrit);
        config.rmin = SafeCast.toInt256(_default.rmin);
        config.rcritMin = SafeCast.toInt256(_default.rcritMin);
        config.rcritMax = SafeCast.toInt256(_default.rcritMax);
        config.r100 = SafeCast.toInt256(_default.r100);
        config.t1 = SafeCast.toInt256(_default.t1);
        config.t2 = SafeCast.toInt256(_default.t2);
        config.tMinus = SafeCast.toInt256(_default.tMinus);
        config.tPlus = SafeCast.toInt256(_default.tPlus);
        config.tMin = SafeCast.toInt256(_default.tMin);
    }
}
