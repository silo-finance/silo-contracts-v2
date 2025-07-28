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
        // uint256 dp = uint256(_DP);

        // require(_default.ulow >= 0, IDynamicKinkModel.InvalidUlow());
        // require(_default.u1 > _default.ulow, IDynamicKinkModel.InvalidU1());
        // require(_default.u2 > _default.u1, IDynamicKinkModel.InvalidU2());
        // require(_default.ucrit > _default.u2 && _default.ucrit <= dp, IDynamicKinkModel.InvalidUcrit());

        // require(_default.rmin >= 0, IDynamicKinkModel.InvalidRmin());
        // require(_default.rcritMin > _default.rmin, IDynamicKinkModel.InvalidRcritMin());
        // require(
        //     _default.rcritMax >= _default.rcritMin && _default.rcritMax <= _default.r100,
        //     IDynamicKinkModel.InvalidRcritMax()
        // );

        // uint256 rCheckHi = (_default.r100 - _default.rcritMin) / (_default.rcritMax - _default.rcritMin);
        // uint256 rCheckLo = (dp - _default.ucrit) / (_default.ucrit - _default.ulow);
        // require(rCheckHi >= rCheckLo, IDynamicKinkModel.InvalidDefaultConfig());

        // require(_default.tMin > 0, IDynamicKinkModel.InvalidTMin());
        // require(_default.tPlus >= _default.tMin, IDynamicKinkModel.InvalidTPlus());
        // require(_default.t2 >= _default.tPlus && _default.t2 <= 100 * 365 days, IDynamicKinkModel.InvalidT2());

        // require(_default.tMinus > 0, IDynamicKinkModel.InvalidTMinus());
        // require(_default.t1 >= _default.tMinus && _default.t1 <= 100 * 365 days, IDynamicKinkModel.InvalidT1());

        // uint256 s = 365 days;

        // config.rmin = SafeCast.toInt256(_default.rmin / s);
        // config.kmin = SafeCast.toInt256((_default.rcritMin - _default.rmin) / (_default.ucrit - _default.ulow) / s);
        // config.kmax = SafeCast.toInt256((_default.rcritMax - _default.rmin) / (_default.ucrit - _default.ulow) / s);

        // config.alpha = SafeCast.toInt256(
        //     (_default.r100 - _default.rmin - s * config.kmax * (dp - _default.ulow))
        //         / (s * config.kmax * (dp - _default.ucrit))
        // );

        // config.c1 = (config.kmax - config.kmin) / SafeCast.toInt256(_default.t1);
        // config.c2 = (config.kmax - config.kmin) / SafeCast.toInt256(_default.t2);
        
        // config.cminus = ((config.kmax - config.kmin) / SafeCast.toInt256(_default.tMinus) - config.c1) 
        //         / SafeCast.toInt256(_default.u1 - _default.ulow);
        
        // config.cplus = ((config.kmax - config.kmin) / SafeCast.toInt256(_default.tPlus) - config.c2) 
        //     / SafeCast.toInt256(_default.ucrit - _default.u2);
        
        // config.dmax = (config.kmax - config.kmin) / SafeCast.toInt256(_default.tMin);

        // IDynamicKinkModel(address(IRM)).verifyConfig(config);
    }

    // tODO /// @inheritdoc IDynamicKinkModelFactory
    function verifyConfig(IDynamicKinkModel.Config calldata _config) external view virtual {
        IDynamicKinkModel(address(IRM)).verifyConfig(_config);
    }

    /// @inheritdoc IDynamicKinkModelFactory
    function hashConfig(IDynamicKinkModel.Config calldata _config) public pure virtual returns (bytes32 configId) {
        configId = keccak256(abi.encode(_config));
    }
}
