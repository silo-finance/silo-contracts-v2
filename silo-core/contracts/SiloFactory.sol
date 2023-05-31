// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.17;

import "openzeppelin-contracts-upgradeable/contracts/utils/CountersUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/ClonesUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

import "./interface/IShareToken.sol";
import "./SiloConfig.sol";
import "./Silo.sol";

contract SiloFactory is Initializable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private siloId;

    address public siloImpl;
    address public shareCollateralTokenImpl;
    address public shareDebtTokenImpl;

    mapping(uint256 => address) public idToSilo;
    mapping(address => uint256) public siloToId;

    error ZeroAddress();

    function initialize(
        address _siloImpl,
        address _shareCollateralTokenImpl,
        address _shareDebtTokenImpl
    ) external initializer {
        if (
            _siloImpl == address(0) ||
            _shareCollateralTokenImpl == address(0) ||
            _shareDebtTokenImpl == address(0)
        ) revert ZeroAddress();

        siloImpl = _siloImpl;
        shareCollateralTokenImpl = _shareCollateralTokenImpl;
        shareDebtTokenImpl = _shareDebtTokenImpl;
    }

    function getNextSiloId() external view returns (uint256) {
        return siloId.current();
    }

    /// @param _assets addresses of assets for which this Silo is deployed.
    /// Indexes:
    ///   0: token0
    ///   1: token1
    /// @param _oracles addresses of oracles used for LTV and LT calculations. If address(0) is used then the value
    /// of 1 is assumed. For example, if address(0) is used for ETH oracle, request to price 20 ETH will return 20 ETH.
    /// Indexes:
    ///   0: token0 - ltvOracle
    ///   1: token0 - ltOracle
    ///   2: token1 - ltvOracle
    ///   3: token1 - ltOracle
    /// @param _interestRateModel addresses of interest rate models
    /// Indexes:
    ///   0: token0 - interestRateModel
    ///   1: token1 - interestRateModel
    /// @param _maxLtv maximum LTV values for each token
    /// Indexes:
    ///   0: token0 - maxLtv
    ///   1: token1 - maxLtv
    /// @param _lt liquidation threshold values for each token
    /// Indexes:
    ///   0: token0 - lt
    ///   1: token1 - lt
    /// @param _borrowable if true, token can be borrowed. If false, one sided market will be created. Reverts if
    /// both tokens are set to false.
    /// Indexes:
    ///   0: token0 - borrowable
    ///   1: token1 - borrowable
    function createSilo(
        address[2] memory _assets,
        address[4] memory _oracles,
        address[2] memory _interestRateModel,
        uint256[2] memory _maxLtv,
        uint256[2] memory _lt,
        bool[2] memory _borrowable
    ) public {
        uint256 nextSiloId = siloId.current();
        siloId.increment();

        address[6] memory shareTokens;

        shareTokens[0] = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        shareTokens[1] = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        shareTokens[2] = ClonesUpgradeable.clone(shareDebtTokenImpl);

        shareTokens[3] = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        shareTokens[4] = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        shareTokens[5] = ClonesUpgradeable.clone(shareDebtTokenImpl);

        address siloConfig = address(new SiloConfig(
            nextSiloId,
            _assets,
            shareTokens,
            _oracles,
            _interestRateModel,
            _maxLtv,
            _lt,
            _borrowable
        ));

        address silo = ClonesUpgradeable.clone(siloImpl);
        ISilo(silo).initialize(ISiloConfig(siloConfig));

        // TODO: mappings
        siloToId[silo] = nextSiloId;
        idToSilo[nextSiloId] = silo;

        // TODO: token names

        IShareToken(shareTokens[0]).initialize("name", "symbol", ISilo(silo), _assets[0]);
        IShareToken(shareTokens[1]).initialize("name", "symbol", ISilo(silo), _assets[0]);
        IShareToken(shareTokens[2]).initialize("name", "symbol", ISilo(silo), _assets[0]);
        
        IShareToken(shareTokens[3]).initialize("name", "symbol", ISilo(silo), _assets[1]);
        IShareToken(shareTokens[4]).initialize("name", "symbol", ISilo(silo), _assets[1]);
        IShareToken(shareTokens[5]).initialize("name", "symbol", ISilo(silo), _assets[1]);

        // TODO: AMM deployment
    }
}
