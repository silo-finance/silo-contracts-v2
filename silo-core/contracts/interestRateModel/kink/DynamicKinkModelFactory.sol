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

/// @title DynamicKinkModelFactory
/// @dev It creates DynamicKinkModelConfig.
contract DynamicKinkModelFactory is Create2Factory, IDynamicKinkModelFactory {
    /// @dev DP in 18 decimal points used for integer calculations
    int256 internal constant _DP = int256(1e18);

    /// @dev IRM contract implementation address to clone
    address public immutable IRM;

    /// Config hash is determine by initial configuration, the logic is the same, so config is the only difference
    /// that's why we can use it as ID, at the same time we can detect duplicated and save gas by reusing same config
    /// multiple times
    mapping(bytes32 configHash => IDynamicKinkModel) public irmByConfigHash;

    constructor() {
        IRM = address(new DynamicKinkModel());
    }

    /// @inheritdoc IDynamicKinkModelFactory
    function create(IDynamicKinkModel.Config calldata _config, bytes32 _externalSalt)
        external
        virtual
        returns (bytes32 configHash, IDynamicKinkModel irm)
    {
        configHash = hashConfig(_config);

        irm = irmByConfigHash[configHash];

        if (address(irm) != address(0)) {
            return (configHash, irm);
        }

        IDynamicKinkModel(address(IRM)).verifyConfig(_config);

        bytes32 salt = _salt(_externalSalt);

        address configContract = address(new DynamicKinkModelConfig{salt: salt}(_config));

        irm = IDynamicKinkModel(Clones.cloneDeterministic(IRM, salt));
        IInterestRateModel(address(irm)).initialize(configContract);

        irmByConfigHash[configHash] = irm;

        emit NewDynamicKinkModel(configHash, irm);
    }

    /// @inheritdoc IDynamicKinkModelFactory
    function DP() external view virtual override returns (uint256) { // solhint-disable-line func-name-mixedcase
        return uint256(_DP);
    }

    /// @inheritdoc IDynamicKinkModelFactory
    // solhint-disable-next-line code-complexity, function-max-lines
    function generateDefaultConfig(IDynamicKinkModel.DefaultConfig calldata _default)
        external
        view
        virtual
        returns (IDynamicKinkModel.Config memory config)
    {
        IDynamicKinkModel.DefaultConfigInt memory defaultInt = _copyDefaultConfig(_default);

        require(defaultInt.ulow >= 0, IDynamicKinkModel.InvalidUlow());
        require(defaultInt.u1 > defaultInt.ulow, IDynamicKinkModel.InvalidU1());
        require(defaultInt.u2 > defaultInt.u1, IDynamicKinkModel.InvalidU2());
        require(defaultInt.ucrit > defaultInt.u2 && defaultInt.ucrit <= _DP, IDynamicKinkModel.InvalidUcrit());

        require(defaultInt.rmin >= 0, IDynamicKinkModel.InvalidRmin());
        require(defaultInt.rcritMin > defaultInt.rmin, IDynamicKinkModel.InvalidRcritMin());
        require(
            defaultInt.rcritMax >= defaultInt.rcritMin && defaultInt.rcritMax <= defaultInt.r100,
            IDynamicKinkModel.InvalidRcritMax()
        );

        int256 rCheckHi = (defaultInt.r100 - defaultInt.rcritMin) / (defaultInt.rcritMax - defaultInt.rcritMin);
        int256 rCheckLo = (_DP - defaultInt.ucrit) / (defaultInt.ucrit - defaultInt.ulow);
        require(rCheckHi >= rCheckLo, IDynamicKinkModel.InvalidDefaultConfig());

        require(defaultInt.tMin > 0, IDynamicKinkModel.InvalidTMin());
        require(defaultInt.tPlus >= defaultInt.tMin, IDynamicKinkModel.InvalidTPlus());
        require(defaultInt.t2 >= defaultInt.tPlus && defaultInt.t2 <= 100 * 365 days, IDynamicKinkModel.InvalidT2());

        require(defaultInt.tMinus > 0, IDynamicKinkModel.InvalidTMinus());
        require(defaultInt.t1 >= defaultInt.tMinus && defaultInt.t1 <= 100 * 365 days, IDynamicKinkModel.InvalidT1());

        int256 s = 365 days;

        config.rmin = defaultInt.rmin / s;
        config.kmin = (defaultInt.rcritMin - defaultInt.rmin) / (defaultInt.ucrit - defaultInt.ulow) / s;
        config.kmax = (defaultInt.rcritMax - defaultInt.rmin) / (defaultInt.ucrit - defaultInt.ulow) / s;

        config.alpha = (defaultInt.r100 - defaultInt.rmin - s * config.kmax * (_DP - defaultInt.ulow))
                / (s * config.kmax * (_DP - defaultInt.ucrit));

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
        IDynamicKinkModel(address(IRM)).verifyConfig(_config);
    }

    /// @inheritdoc IDynamicKinkModelFactory
    function hashConfig(IDynamicKinkModel.Config calldata _config) public pure virtual returns (bytes32 configId) {
        configId = keccak256(abi.encode(_config));
    }

    function _copyDefaultConfig(
        IDynamicKinkModel.DefaultConfig calldata _default
    ) internal pure returns (IDynamicKinkModel.DefaultConfigInt memory config) {
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
