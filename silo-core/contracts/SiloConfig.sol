// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {ISiloConfig} from "./interfaces/ISiloConfig.sol";

/// @notice SiloConfig stores full configuration of Silo in immutable manner
/// @dev Immutable contract is more expensive to deploy than minimal proxy however it provides nearly 10x cheapper
/// data access using immutable variables.
contract SiloConfig is ISiloConfig {
    /// @dev 1e18 == 100%
    uint256 public constant ONE = 1e18;

    uint256 public immutable SILO_ID; // solhint-disable-line var-name-mixedcase

    // TOKEN #0

    address public immutable TOKEN0; // solhint-disable-line var-name-mixedcase

    /// @dev Token that represents a share in total protected deposits of Silo
    address public immutable PROTECTED_COLLATERAL_SHARE_TOKEN0; // solhint-disable-line var-name-mixedcase
    /// @dev Token that represents a share in total deposits of Silo
    address public immutable COLLATERAL_SHARE_TOKEN0; // solhint-disable-line var-name-mixedcase
    /// @dev Token that represents a share in total debt of Silo
    address public immutable DEBT_SHARE_TOKEN0; // solhint-disable-line var-name-mixedcase

    address public immutable LTV_ORACLE0; // solhint-disable-line var-name-mixedcase
    address public immutable LT_ORACLE0; // solhint-disable-line var-name-mixedcase

    address public immutable INTEREST_RATE_MODEL0; // solhint-disable-line var-name-mixedcase

    uint64 public immutable MAX_LTV0; // solhint-disable-line var-name-mixedcase
    uint64 public immutable LT0; // solhint-disable-line var-name-mixedcase

    bool public immutable BORROWABLE0; // solhint-disable-line var-name-mixedcase

    // TOKEN #1

    address public immutable TOKEN1; // solhint-disable-line var-name-mixedcase

    /// @dev Token that represents a share in total protected deposits of Silo
    address public immutable PROTECTED_COLLATERAL_SHARE_TOKEN1; // solhint-disable-line var-name-mixedcase
    /// @dev Token that represents a share in total deposits of Silo
    address public immutable COLLATERAL_SHARE_TOKEN1; // solhint-disable-line var-name-mixedcase
    /// @dev Token that represents a share in total debt of Silo
    address public immutable DEBT_SHARE_TOKEN1; // solhint-disable-line var-name-mixedcase

    address public immutable LTV_ORACLE1; // solhint-disable-line var-name-mixedcase
    address public immutable LT_ORACLE1; // solhint-disable-line var-name-mixedcase

    address public immutable INTEREST_RATE_MODEL1; // solhint-disable-line var-name-mixedcase

    uint64 public immutable MAX_LTV1; // solhint-disable-line var-name-mixedcase
    uint64 public immutable LT1; // solhint-disable-line var-name-mixedcase

    bool public immutable BORROWABLE1; // solhint-disable-line var-name-mixedcase

    /// @param _siloId ID of this pool assigned by factory
    /// @param _configData silo configuration data
    constructor(uint256 _siloId, ConfigData memory _configData) {
        validateSiloConfig(_configData);

        SILO_ID = _siloId;

        // TODO: sort tokens, token0 < token1, use two structs

        // TOKEN #0

        TOKEN0 = _configData.token0;

        PROTECTED_COLLATERAL_SHARE_TOKEN0 = _configData.protectedCollateralShareToken0;
        COLLATERAL_SHARE_TOKEN0 = _configData.collateralShareToken0;
        DEBT_SHARE_TOKEN0 = _configData.debtShareToken0;

        LTV_ORACLE0 = _configData.ltvOracle0;
        LT_ORACLE0 = _configData.ltOracle0;

        INTEREST_RATE_MODEL0 = _configData.interestRateModel0;

        MAX_LTV0 = _configData.maxLtv0;
        LT0 = _configData.lt0;

        BORROWABLE0 = _configData.borrowable0;

        // TOKEN #1

        TOKEN1 = _configData.token1;

        PROTECTED_COLLATERAL_SHARE_TOKEN1 = _configData.protectedCollateralShareToken1;
        COLLATERAL_SHARE_TOKEN1 = _configData.collateralShareToken1;
        DEBT_SHARE_TOKEN1 = _configData.debtShareToken1;

        LTV_ORACLE1 = _configData.ltvOracle1;
        LT_ORACLE1 = _configData.ltOracle1;

        INTEREST_RATE_MODEL1 = _configData.interestRateModel1;

        MAX_LTV1 = _configData.maxLtv1;
        LT1 = _configData.lt1;

        BORROWABLE1 = _configData.borrowable1;
    }

    function getConfig() public view returns (ConfigData memory) {
        return ConfigData({
            token0: TOKEN0,
            protectedCollateralShareToken0: PROTECTED_COLLATERAL_SHARE_TOKEN0,
            collateralShareToken0: COLLATERAL_SHARE_TOKEN0,
            debtShareToken0: DEBT_SHARE_TOKEN0,
            ltvOracle0: LTV_ORACLE0,
            ltOracle0: LT_ORACLE0,
            interestRateModel0: INTEREST_RATE_MODEL0,
            maxLtv0: MAX_LTV0,
            lt0: LT0,
            borrowable0: BORROWABLE0,
            token1: TOKEN1,
            protectedCollateralShareToken1: PROTECTED_COLLATERAL_SHARE_TOKEN1,
            collateralShareToken1: COLLATERAL_SHARE_TOKEN1,
            debtShareToken1: DEBT_SHARE_TOKEN1,
            ltvOracle1: LTV_ORACLE1,
            ltOracle1: LT_ORACLE1,
            interestRateModel1: INTEREST_RATE_MODEL1,
            maxLtv1: MAX_LTV1,
            lt1: LT1,
            borrowable1: BORROWABLE1
        });
    }

    function validateSiloConfig(ConfigData memory _configData) public pure { // solhint-disable-line code-complexity
        if (_configData.token0 == _configData.token1) revert SameAsset();
        if (_configData.interestRateModel0 == address(0) || _configData.interestRateModel1 == address(0)) {
            revert InvalidIrm();
        }
        if (_configData.maxLtv0 > _configData.lt0) revert InvalidMaxLtv();
        if (_configData.maxLtv1 > _configData.lt1) revert InvalidMaxLtv();
        if (_configData.maxLtv0 == 0 && _configData.maxLtv1 == 0) revert InvalidMaxLtv();
        if (_configData.lt0 >= ONE || _configData.lt1 >= ONE) revert InvalidLt();
        if (!_configData.borrowable0 && !_configData.borrowable1) revert NonBorrowableSilo();

        if (_configData.protectedCollateralShareToken0 == address(0)) revert InvalidShareTokens();
        if (_configData.collateralShareToken0 == address(0)) revert InvalidShareTokens();
        if (_configData.debtShareToken0 == address(0)) revert InvalidShareTokens();
        if (_configData.protectedCollateralShareToken1 == address(0)) revert InvalidShareTokens();
        if (_configData.collateralShareToken1 == address(0)) revert InvalidShareTokens();
        if (_configData.debtShareToken1 == address(0)) revert InvalidShareTokens();
    }
}
