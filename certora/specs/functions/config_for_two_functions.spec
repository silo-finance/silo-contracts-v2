/* Functions implementing `SiloConfig` for two silos
 *
 * See `summaries/config_for_two_in_cvl.spec` - where this is used.
 * See `meta/config_for_two_equivalence.spec` - where equivalence with `SiloConfig`
 * functions is verified.
 */

// To keep the contract aliases unique, we added the suffix `_CC` (for `CVL Config`)
using SiloConfig as siloConfig_CC;

using Silo0 as silo0_CC;
using Silo1 as silo1_CC;

using ShareDebtToken0 as shareDebtToken0_CC;
using ShareProtectedCollateralToken0 as shareProtectedCollateralToken0_CC;

using ShareDebtToken1 as shareDebtToken1_CC;
using ShareProtectedCollateralToken1 as shareProtectedCollateralToken1_CC;

using Token0 as token0_CC;
using Token1 as token1_CC;

// ---- Implementations --------------------------------------------------------

/// @title Implements `SiloConfig.getSilos` in CVL
function CVLGetSilos() returns (address, address) {
    return (silo0_CC, silo1_CC);
}


/// @title Implements `SiloConfig.getShareTokens` in CVL
/// @notice Assumes each silo is also the collateral share token!
function CVLGtShareTokens(address _silo) returns (address, address, address) {
    require _silo == silo0_CC || _silo == silo1_CC;  // TODO: change to assert?
    if (_silo == siloConfig_CC._SILO0) {
        return (shareProtectedCollateralToken0_CC, silo0_CC, shareDebtToken0_CC);
    } else {
        return (shareProtectedCollateralToken1_CC, silo1_CC, shareDebtToken1_CC);
    }
}



/// @title Implements `SiloConfig.getAssetForSilo` in CVL
function CVLGetAssetForSilo(address _silo) returns address {
    require _silo == silo0_CC || _silo == silo1_CC;  // TODO: change to assert?
    if (_silo == siloConfig_CC._SILO0) {
        return token0_CC;
    } else {
        return token1_CC;
    }
}


/// @title Implements `SiloConfig.getFeesWithAsset` in CVL
function CVLGetFeesWithAsset(address _silo) returns (uint256, uint256, uint256, address) {
    require _silo == silo0_CC || _silo == silo1_CC;  // TODO: change to assert?
    if (_silo == siloConfig_CC._SILO0) {
        return (
            siloConfig_CC._DAO_FEE,
            siloConfig_CC._DEPLOYER_FEE,
            siloConfig_CC._FLASHLOAN_FEE0,
            token0_CC
        );
    } else {
        return (
            siloConfig_CC._DAO_FEE,
            siloConfig_CC._DEPLOYER_FEE,
            siloConfig_CC._FLASHLOAN_FEE1,
            token1_CC
        );
    }
}


/// @title Implements `SiloConfig.getCollateralShareTokenAndAsset` in CVL
/// @notice Assumes each silo is also the collateral share token!
function CVLGetCollateralShareTokenAndAsset(
    address _silo,
    ISilo.CollateralType _collateralType
) returns (address, address) {
    require _silo == silo0_CC || _silo == silo1_CC;  // TODO: change to assert?
    if (_silo == siloConfig_CC._SILO0) {
        if (_collateralType == ISilo.CollateralType.Collateral) {
            return (silo0_CC, token0_CC);
        } else {
            return (shareProtectedCollateralToken0_CC, token0_CC);
        }
    } else {
        if (_collateralType == ISilo.CollateralType.Collateral) {
            return (silo1_CC, token1_CC);
        } else {
            return (shareProtectedCollateralToken1_CC, token1_CC);
        }
    }
}


/// @title Implements `SiloConfig.getDebtShareTokenAndAsset` in CVL
function CVLGetDebtShareTokenAndAsset(address _silo) returns (address, address) {
    require _silo == silo0_CC || _silo == silo1_CC;  // TODO: change to assert?
    if (_silo == siloConfig_CC._SILO0) {
        return (shareDebtToken0_CC, token0_CC);
    } else {
        return (shareDebtToken1_CC, token1_CC);
    }
}
