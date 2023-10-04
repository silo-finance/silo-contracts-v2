// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface ISiloConfig {
    struct InitData {
        address deployer;
        uint256 deployerFeeInBp;
        address token0;
        address solvencyOracle0;
        address maxLtvOracle0;
        address interestRateModel0;
        address interestRateModelConfig0;
        uint64 maxLtv0;
        uint64 lt0;
        uint64 liquidationFee0;
        uint64 flashloanFee0;
        // TODO: borrowable0 is redundant because the same can be achieved with maxLTV = 0
        bool borrowable0;
        address protectedHookReceiver0;
        address collateralHookReceiver0;
        address debtHookReceiver0;
        address token1;
        address solvencyOracle1;
        address maxLtvOracle1;
        address interestRateModel1;
        address interestRateModelConfig1;
        uint64 maxLtv1;
        uint64 lt1;
        uint64 liquidationFee1;
        uint64 flashloanFee1;
        // TODO: borrowable1 is redundant because the same can be achieved with maxLTV = 0
        bool borrowable1;
        address protectedHookReceiver1;
        address collateralHookReceiver1;
        address debtHookReceiver1;
    }

    struct ConfigData { // TODO check all places where we using it and try to oprimise
        uint256 daoFeeInBp;
        uint256 deployerFeeInBp;
        address silo;
        address otherSilo;
        address token;
        address protectedShareToken;
        address collateralShareToken;
        address debtShareToken;
        address solvencyOracle;
        address maxLtvOracle;
        address interestRateModel;
        uint64 maxLtv;
        uint64 lt;
        uint64 liquidationFee;
        uint64 flashloanFee;
        bool borrowable;
    }

    error WrongSilo();

    // solhint-disable-next-line func-name-mixedcase
    function SILO_ID() external view returns (uint256);

    function getSilos() external view returns (address, address);
    function getAssetForSilo(address _silo) external view returns (address asset);
    function getConfigs(address _silo) external view returns (ConfigData memory, ConfigData memory);
    function getConfig(address _silo) external view returns (ConfigData memory);
    function getFeesWithAsset(address _silo)
        external
        view
        returns (uint256 daoFeeInBp, uint256 deployerFeeInBp, uint256 flashloanFeeInBp, address asset);

    function getShareTokens(address _silo)
        external
        view
        returns (address protectedShareToken, address collateralShareToken, address debtShareToken);
}
