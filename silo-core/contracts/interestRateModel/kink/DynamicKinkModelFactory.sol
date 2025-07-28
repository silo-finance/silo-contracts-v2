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
    int256 internal constant _DP = 1e18;

    /// @dev universal limit for several DynamicKinkModel config parameters. Follow the model whitepaper for more
    ///     information. Units of measure are vary per variable type. Any config within these limits is considered
    ///     valid.
    int256 public constant UNIVERSAL_LIMIT = 1e9 * _DP;

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
    function DP() external view virtual override returns (uint256) {
        return uint256(_DP);
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

        verifyConfig(_config);

        bytes32 salt = _salt(_externalSalt);

        address configContract = address(new DynamicKinkModelConfig{salt: salt}(_config));

        irm = IDynamicKinkModel(Clones.cloneDeterministic(IRM, salt));
        IInterestRateModel(address(irm)).initialize(configContract);

        irmByConfigHash[configHash] = irm;

        emit NewDynamicKinkModel(configHash, irm);
    }

    /// @inheritdoc IDynamicKinkModelFactory
    function generateDefaultConfig(IDynamicKinkModel.DefaultConfig calldata _default)
        external
        view
        virtual
        returns (IDynamicKinkModel.Config memory config)
    {
        require(_default.ulow >= 0, IDynamicKinkModel.InvalidUlow());
        require(_default.u1 > _default.ulow, IDynamicKinkModel.InvalidU1());
        require(_default.u2 > _default.u1, IDynamicKinkModel.InvalidU2());
        require(_default.ucrit > _default.u2 && _default.ucrit <= _DP, IDynamicKinkModel.InvalidUcrit());

        require(_default.rmin >= 0, IDynamicKinkModel.InvalidRmin());
        require(_default.rcritMin > _default.rmin, IDynamicKinkModel.InvalidRcritMin());
        require(
            _default.rcritMax >= _default.rcritMin && _default.rcritMax <= _default.r100,
            IDynamicKinkModel.InvalidRcritMax()
        );

        uint256 rCheckHi = (_default.r100 - _default.rcritMin) / (_default.rcritMax - _default.rcritMin);
        uint256 rCheckLo = (_DP - _default.ucrit) / (_default.ucrit - _default.ulow);
        require(rCheckHi >= rCheckLo, IDynamicKinkModel.InvalidDefaultConfig());

        require(_default.tMin > 0, IDynamicKinkModel.InvalidTMin());
        require(_default.tPlus >= _default.tMin, IDynamicKinkModel.InvalidTPlus());
        require(_default.t2 >= _default.tPlus && _default.t2 <= 100 * 365 days, IDynamicKinkModel.InvalidT2());

        require(_default.tMinus > 0, IDynamicKinkModel.InvalidTMinus());
        require(_default.t1 >= _default.tMinus && _default.t1 <= 100 * 365 days, IDynamicKinkModel.InvalidT1());

        uint256 s = 365 days;

        config.rmin = SafeCast.toInt256(_default.rmin / s);
        config.kmin = SafeCast.toInt256((_default.rcritMin - _default.rmin) / (_default.ucrit - _default.ulow) / s);
        config.kmax = SafeCast.toInt256((_default.rcritMax - _default.rmin) / (_default.ucrit - _default.ulow) / s);

        config.alpha = SafeCast.toInt256(
            (_default.r100 - _default.rmin - s * config.kmax * (_DP - _default.ulow))
                / (s * config.kmax * (_DP - _default.ucrit))
        );

        config.c1 = SafeCast.toInt256((config.kmax - config.kmin) / _default.t1);
        config.c2 = SafeCast.toInt256((config.kmax - config.kmin) / _default.t2);
        
        config.cminus = SafeCast.toInt256(
            ((config.kmax - config.kmin) / _default.tMinus - config.c1) / (_default.u1 - _default.ulow)
        );
        
        config.cplus = SafeCast.toInt256(
            ((config.kmax - config.kmin) / _default.tPlus - config.c2) / (_default.ucrit - _default.u2)
        );
        
        config.dmax = SafeCast.toInt256((config.kmax - config.kmin) / _default.tMin);

        verifyConfig(config);
    }

    /// @inheritdoc IDynamicKinkModelFactory
    // solhint-disable-next-line code-complexity
    function verifyConfig(IDynamicKinkModel.Config calldata _config) public view virtual {
        require(_config.ulow >= 0 && _config.ulow < _DP, IDynamicKinkModel.InvalidUlow());
        require(_config.u1 >= 0 && _config.u1 < _DP, IDynamicKinkModel.InvalidU1());
        require(_config.u2 >= _config.u1 && _config.u2 <= _DP, IDynamicKinkModel.InvalidU2());
        require(_config.ucrit >= _config.ulow && _config.ucrit <= _DP, IDynamicKinkModel.InvalidUcrit());
        require(_config.rmin >= 0 && _config.rmin <= _DP, IDynamicKinkModel.InvalidRmin());
        require(_config.kmin >= 0 && _config.kmin <= UNIVERSAL_LIMIT, IDynamicKinkModel.InvalidKmin());
        require(_config.kmax >= _config.kmin && _config.kmin <= UNIVERSAL_LIMIT, IDynamicKinkModel.InvalidKmax());
        require(_config.alpha >= 0 && _config.alpha <= UNIVERSAL_LIMIT, IDynamicKinkModel.InvalidAlpha());
        require(_config.cminus >= 0 && _config.cminus <= UNIVERSAL_LIMIT, IDynamicKinkModel.InvalidCminus());
        require(_config.cplus >= 0 && _config.cplus <= UNIVERSAL_LIMIT, IDynamicKinkModel.InvalidCplus());
        require(_config.c1 >= 0 && _config.c1 <= UNIVERSAL_LIMIT, IDynamicKinkModel.InvalidC1());
        require(_config.c2 >= 0 && _config.c2 <= UNIVERSAL_LIMIT, IDynamicKinkModel.InvalidC2());
        // TODO do we still need upper limit
        require(_config.dmax >= _contig.c2 && _config.dmax < UNIVERSAL_LIMIT, IDynamicKinkModel.InvalidDmax());

        // overflow check
        // DynamicKinkModel(IRM).configOverflowCheck(_config); TODO
    }

    /// @inheritdoc IDynamicKinkModelFactory
    function hashConfig(IDynamicKinkModel.Config calldata _config) public pure virtual returns (bytes32 configId) {
        configId = keccak256(abi.encode(_config));
    }
}
