// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {CountersUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/CountersUpgradeable.sol";
import {ClonesUpgradeable} from  "openzeppelin-contracts-upgradeable/contracts/proxy/ClonesUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

import {IShareToken} from "./interface/IShareToken.sol";
import {ISiloConfig, SiloConfig} from "./SiloConfig.sol";
import {ISilo, Silo} from "./Silo.sol";

contract SiloFactory is Initializable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _siloId;

    address public siloImpl;
    address public shareCollateralTokenImpl;
    address public shareDebtTokenImpl;

    mapping(uint256 => address) public idToSilo;
    mapping(address => uint256) public siloToId;

    error ZeroAddress();

    function initialize(address _siloImpl, address _shareCollateralTokenImpl, address _shareDebtTokenImpl)
        external
        initializer
    {
        if (_siloImpl == address(0) || _shareCollateralTokenImpl == address(0) || _shareDebtTokenImpl == address(0)) {
            revert ZeroAddress();
        }

        siloImpl = _siloImpl;
        shareCollateralTokenImpl = _shareCollateralTokenImpl;
        shareDebtTokenImpl = _shareDebtTokenImpl;
    }

    function getNextSiloId() external view returns (uint256) {
        return _siloId.current();
    }

    /// @param _configData silo configuration data
    /// @dev share tokens in _configData are overridden so can be set to address(0). Sanity data validation 
    ///      is done by SiloConfig.
    function createSilo(ISiloConfig.ConfigData memory _configData) public {
        uint256 nextSiloId = _siloId.current();
        _siloId.increment();

        _configData.protectedCollateralShareToken0 = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        _configData.collateralShareToken0 = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        _configData.debtShareToken0 = ClonesUpgradeable.clone(shareDebtTokenImpl);

        _configData.protectedCollateralShareToken1 = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        _configData.collateralShareToken1 = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        _configData.debtShareToken1 = ClonesUpgradeable.clone(shareDebtTokenImpl);

        address siloConfig = address(new SiloConfig(nextSiloId, _configData));

        address silo = ClonesUpgradeable.clone(siloImpl);
        ISilo(silo).initialize(ISiloConfig(siloConfig));

        // TODO: mappings
        siloToId[silo] = nextSiloId;
        idToSilo[nextSiloId] = silo;

        // TODO: token names

        IShareToken(_configData.protectedCollateralShareToken0).initialize(
            "name", "symbol", ISilo(silo), _configData.token0
        );
        IShareToken(_configData.collateralShareToken0).initialize("name", "symbol", ISilo(silo), _configData.token0);
        IShareToken(_configData.debtShareToken0).initialize("name", "symbol", ISilo(silo), _configData.token0);

        IShareToken(_configData.protectedCollateralShareToken1).initialize(
            "name", "symbol", ISilo(silo), _configData.token1
        );
        IShareToken(_configData.collateralShareToken1).initialize("name", "symbol", ISilo(silo), _configData.token1);
        IShareToken(_configData.debtShareToken1).initialize("name", "symbol", ISilo(silo), _configData.token1);

        // TODO: AMM deployment
    }
}
