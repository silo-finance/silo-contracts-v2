// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.17;

import "./interface/ISiloConfig.sol";

/// @notice SiloConfig stores full configuration of Silo in immutable manner
/// @dev Immutable contract is more expensive to deploy than minimal proxy however it provides nearly 10x cheapper
/// data access using immutable variables.
contract SiloConfig is ISiloConfig {
    uint256 public immutable SILO_ID;

    /**
     * TOKEN #0
     */

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

    /**
     * TOKEN #1
     */

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
    /// @param _configData silo configuration data
    constructor(uint256 _siloId, ConfigData memory _configData) {
        validateSiloData(_configData);

        SILO_ID = _siloId;

        /**
         * TOKEN #0
         */

        token0 = _configData.token0;

        protectedCollateralShareToken0 = _configData.protectedCollateralShareToken0;
        collateralShareToken0 = _configData.collateralShareToken0;
        debtShareToken0 = _configData.debtShareToken0;

        ltvOracle0 = _configData.ltvOracle0;
        ltOracle0 = _configData.ltOracle0;

        interestRateModel0 = _configData.interestRateModel0;

        maxLtv0 = _configData.maxLtv0;
        lt0 = _configData.lt0;

        borrowable0 = _configData.borrowable0;

        /**
         * TOKEN #1
         */

        token1 = _configData.token1;

        protectedCollateralShareToken1 = _configData.protectedCollateralShareToken1;
        collateralShareToken1 = _configData.collateralShareToken1;
        debtShareToken1 = _configData.debtShareToken1;

        ltvOracle1 = _configData.ltvOracle1;
        ltOracle1 = _configData.ltOracle1;

        interestRateModel1 = _configData.interestRateModel1;

        maxLtv1 = _configData.maxLtv1;
        lt1 = _configData.lt1;

        borrowable1 = _configData.borrowable1;
    }

    function validateSiloData(ConfigData memory _configData) public pure {
        if (_configData.token0 == _configData.token1) revert SameAsset();
        if (_configData.interestRateModel0 == address(0) || _configData.interestRateModel1 == address(0)) {
            revert InvalidIrm();
        }
        if (_configData.maxLtv0 > _configData.lt0) revert InvalidMaxLtv();
        if (_configData.maxLtv1 > _configData.lt1) revert InvalidMaxLtv();
        if (_configData.maxLtv0 == 0 && _configData.maxLtv1 == 0) revert InvalidMaxLtv();
        if (!_configData.borrowable0 && !_configData.borrowable1) revert NonBorrowableSilo();

        if (_configData.protectedCollateralShareToken0 == address(0)) revert InvalidShareTokens();
        if (_configData.collateralShareToken0 == address(0)) revert InvalidShareTokens();
        if (_configData.debtShareToken0 == address(0)) revert InvalidShareTokens();
        if (_configData.protectedCollateralShareToken1 == address(0)) revert InvalidShareTokens();
        if (_configData.collateralShareToken1 == address(0)) revert InvalidShareTokens();
        if (_configData.debtShareToken1 == address(0)) revert InvalidShareTokens();
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
