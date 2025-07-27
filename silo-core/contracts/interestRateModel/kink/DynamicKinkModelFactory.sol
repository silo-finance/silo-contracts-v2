// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";

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
        // TODO here is conflicted info - whitepaper Dmax => c2, but internal doc [0, LIMIT]
        require(_config.dmax >= 0 && _config.dmax < UNIVERSAL_LIMIT, IDynamicKinkModel.InvalidDmax());

        // overflow check
        // DynamicKinkModel(IRM).configOverflowCheck(_config); TODO
    }

    /// @inheritdoc IDynamicKinkModelFactory
    function hashConfig(IDynamicKinkModel.Config calldata _config)
        public
        pure
        virtual
        returns (bytes32 configId)
    {
        configId = keccak256(abi.encode(_config));
    }
}
