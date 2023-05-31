// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.17;

import "./interface/ISiloConfig.sol";

/// @notice SiloConfig stores full configuration of Silo in immutable manner
/// @dev Immutable contract is more expensive to deploy than minimal proxy however it provides nearly 10x cheapper
/// data access using immutable variables.
contract SiloConfig is ISiloConfig {
    uint256 public immutable siloId;

    /******* TOKEN #0 *******/

    address public immutable token0;

    /// @dev Token that represents a share in total protected deposits of Silo
    address public immutable protectedCollateralShareToken0;
    /// @dev Token that represents a share in total deposits of Silo
    address public immutable collateralShareToken0;
    /// @dev Token that represents a share in total debt of Silo
    address public immutable debtShareToken0;

    address public immutable ltvOracle0;
    address public immutable ltOracle0;

    address public immutable interestRateModel0;

    uint256 public immutable maxLtv0;
    uint256 public immutable lt0;

    bool public immutable borrowable0;

    /******* TOKEN #1 *******/

    address public immutable token1;

    /// @dev Token that represents a share in total protected deposits of Silo
    address public immutable protectedCollateralShareToken1;
    /// @dev Token that represents a share in total deposits of Silo
    address public immutable collateralShareToken1;
    /// @dev Token that represents a share in total debt of Silo
    address public immutable debtShareToken1;

    address public immutable ltvOracle1;
    address public immutable ltOracle1;

    address public immutable interestRateModel1;

    uint256 public immutable maxLtv1;
    uint256 public immutable lt1;

    bool public immutable borrowable1;

    error SameAsset();
    error InvalidIrm();
    error InvalidMaxLtv();
    error NonBorrowableSilo();
    error InvalidShareTokens();

    /// @param _siloId ID of this pool assigned by factory
    /// @param _assets addresses of assets for which this Silo is deployed.
    /// Indexes:
    ///   0: token0
    ///   1: token1
    /// @param _shareTokens addresses of ERC20 share tokens for both assets
    /// Indexes:
    ///   0: token0 - protectedCollateralShareToken
    ///   1: token0 - collateralShareToken
    ///   2: token0 - debtShareToken
    ///   3: token1 - protectedCollateralShareToken
    ///   4: token1 - collateralShareToken
    ///   5: token1 - debtShareToken
    /// @param _oracles addresses of oracles used for LTV and LT calculations
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
    /// @param _borrowable if true, token can be borrowed. If false, one sided market will be created.
    /// Indexes:
    ///   0: token0 - borrowable
    ///   1: token1 - borrowable
    constructor(
        uint256 _siloId,
        address[2] memory _assets,
        address[6] memory _shareTokens,
        address[4] memory _oracles,
        address[2] memory _interestRateModel,
        uint256[2] memory _maxLtv,
        uint256[2] memory _lt,
        bool[2] memory _borrowable
    ) {
        if (_assets[0] == _assets[1]) revert SameAsset();
        if (_interestRateModel[0] == address(0) || _interestRateModel[1] == address(0)) revert InvalidIrm();
        if (_maxLtv[0] > _lt[0]) revert InvalidMaxLtv();
        if (_maxLtv[1] > _lt[1]) revert InvalidMaxLtv();
        if (_maxLtv[0] == 0 && _maxLtv[1] == 0) revert InvalidMaxLtv();
        if (!_borrowable[0] && !_borrowable[1]) revert NonBorrowableSilo();

        for (uint8 i = 0; i < _shareTokens.length; i++) {
            if (_shareTokens[i] == address(0)) revert InvalidShareTokens();
        }

        siloId = _siloId;

        /******* TOKEN #0 *******/

        token0 = _assets[0];

        protectedCollateralShareToken0 = _shareTokens[0];
        collateralShareToken0 = _shareTokens[1];
        debtShareToken0 = _shareTokens[2];

        ltvOracle0 = _oracles[0];
        ltOracle0 = _oracles[1];

        interestRateModel0 = _interestRateModel[0];

        maxLtv0 = _maxLtv[0];
        lt0 = _lt[0];

        borrowable0 = _borrowable[0];

        /******* TOKEN #1 *******/

        token1 = _assets[1];

        protectedCollateralShareToken1 = _shareTokens[3];
        collateralShareToken1 = _shareTokens[4];
        debtShareToken1 = _shareTokens[5];

        ltvOracle1 = _oracles[2];
        ltOracle1 = _oracles[3];

        interestRateModel1 = _interestRateModel[1];

        maxLtv1 = _maxLtv[1];
        lt1 = _lt[1];

        borrowable1 = _borrowable[1];
    }

    function getConfig() public view returns (ConfigData memory) {
        return ConfigData({
            token0: token0,
            protectedCollateralShareToken0: protectedCollateralShareToken0,
            collateralShareToken0: collateralShareToken0,
            debtShareToken0: debtShareToken0,
            ltvOracle0: ltvOracle0,
            ltOracle0: ltOracle0,
            interestRateModel0: interestRateModel0,
            maxLtv0: maxLtv0,
            lt0: lt0,
            borrowable0: borrowable0,
            token1: token1,
            protectedCollateralShareToken1: protectedCollateralShareToken1,
            collateralShareToken1: collateralShareToken1,
            debtShareToken1: debtShareToken1,
            ltvOracle1: ltvOracle1,
            ltOracle1: ltOracle1,
            interestRateModel1: interestRateModel1,
            maxLtv1: maxLtv1,
            lt1: lt1,
            borrowable1: borrowable1
        });
    }
}
