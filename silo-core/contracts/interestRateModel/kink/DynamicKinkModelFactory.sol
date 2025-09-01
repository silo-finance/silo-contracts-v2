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

    mapping(address irm => bool) public createdByFactory;

    constructor(DynamicKinkModel _implementation) {
        IRM = _implementation;
    }

    /// @inheritdoc IDynamicKinkModelFactory
    function create(
        IDynamicKinkModel.Config calldata _config,
        address _initialOwner,
        address _silo,
        bytes32 _externalSalt
    )
        external
        virtual
        returns (IInterestRateModel irm)
    {
        return _create(_config, _initialOwner, _silo, _externalSalt);
    }

    /// @inheritdoc IDynamicKinkModelFactory
    // solhint-disable-next-line code-complexity, function-max-lines
    function generateConfig(IDynamicKinkModel.UserFriendlyConfig calldata _default)
        external
        view
        virtual
        returns (IDynamicKinkModel.Config memory config)
    {
        IDynamicKinkModel.UserFriendlyConfigInt memory defaultInt = _castConfig(_default);

        // 0 <= ulow < u1 < u2 < ucrit < DP
        require(defaultInt.u1.isInside(defaultInt.ulow, defaultInt.u2), IDynamicKinkModel.InvalidU1());
        require(defaultInt.u2.isInside(defaultInt.u1, defaultInt.ucrit), IDynamicKinkModel.InvalidU2());
        require(defaultInt.ucrit.isInside(defaultInt.u2, DP), IDynamicKinkModel.InvalidUcrit());

        config.ulow = defaultInt.ulow;
        config.u1 = defaultInt.u1;
        config.u2 = defaultInt.u2;
        config.ucrit = defaultInt.ucrit;

        // 0 <= rmin < rcritMin <= rcritMax <= r100

        require(
            defaultInt.rcritMin.isInAbove(defaultInt.rmin, defaultInt.rcritMax), IDynamicKinkModel.InvalidRcritMin()
        );

        require(
            defaultInt.rcritMax.isBetween(defaultInt.rcritMin, defaultInt.r100), IDynamicKinkModel.InvalidRcritMax()
        );

        int256 rCheckHi = (defaultInt.r100 - defaultInt.rmin) * DP / (defaultInt.rcritMax - defaultInt.rmin);
        int256 rCheckLo = (DP - defaultInt.ulow) * DP / (defaultInt.ucrit - defaultInt.ulow);
        require(rCheckHi >= rCheckLo, IDynamicKinkModel.InvalidDefaultConfig());

        int256 s = 365 days;

        // 0 < tMin <= tcrit <= t2 < 100y
        require(defaultInt.tcrit.isBetween(defaultInt.tMin, defaultInt.t2), IDynamicKinkModel.InvalidTPlus());
        require(defaultInt.t2.isInBelow(defaultInt.tcrit, 100 * s), IDynamicKinkModel.InvalidT2());

        // 0 < tlow <= t1 < 100y
        require(defaultInt.tlow != 0, IDynamicKinkModel.InvalidTMinus());
        require(defaultInt.t1.isInBelow(defaultInt.tlow, 100 * s), IDynamicKinkModel.InvalidT1());

        config.rmin = defaultInt.rmin / s;

        config.kmin =
            SafeCast.toInt96((defaultInt.rcritMin - defaultInt.rmin) * DP / (defaultInt.ucrit - defaultInt.ulow) / s);

        config.kmax =
            SafeCast.toInt96((defaultInt.rcritMax - defaultInt.rmin) * DP / (defaultInt.ucrit - defaultInt.ulow) / s);

        config.alpha =
            (rCheckHi * (defaultInt.ucrit - defaultInt.ulow) - (DP - defaultInt.ulow) * DP) / (DP - defaultInt.ucrit);

        config.c1 = (config.kmax - config.kmin) / defaultInt.t1;
        config.c2 = (config.kmax - config.kmin) / defaultInt.t2;

        config.cminus =
            ((config.kmax - config.kmin) / defaultInt.tlow - config.c1) * DP / (defaultInt.u1 - defaultInt.ulow);

        config.cplus =
            ((config.kmax - config.kmin) / defaultInt.tcrit - config.c2) * DP / (defaultInt.ucrit - defaultInt.u2);

        config.dmax = (config.kmax - config.kmin) / defaultInt.tMin;

        IDynamicKinkModel(address(IRM)).verifyConfig(config);
    }

    /// @inheritdoc IDynamicKinkModelFactory
    function verifyConfig(IDynamicKinkModel.Config calldata _config) external view virtual {
        IRM.verifyConfig(_config);
    }

    function predictAddress(address _deployer, bytes32 _externalSalt)
        external
        view
        returns (address predictedAddress)
    {
        require(_deployer != address(0), DeployerCannotBeZero());

        predictedAddress = Clones.predictDeterministicAddress(address(IRM), _createSalt(_deployer, _externalSalt));
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

        createdByFactory[address(irm)] = true;
        emit NewDynamicKinkModel(IDynamicKinkModel(address(irm)));
    }

    function _castConfig(IDynamicKinkModel.UserFriendlyConfig calldata _default)
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
        config.tlow = SafeCast.toInt256(_default.tlow);
        config.tcrit = SafeCast.toInt256(_default.tcrit);
        config.tMin = SafeCast.toInt256(_default.tMin);
    }
}
