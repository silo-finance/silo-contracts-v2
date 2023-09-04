// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface ISiloConfig {
    struct InitData {
        address deployer;
        uint256 deployerFee;
        address token0;
        address ltvOracle0;
        address ltOracle0;
        address interestRateModel0;
        uint64 maxLtv0;
        uint64 lt0;
        uint64 liquidationFee0;
        bool borrowable0;
        address protectedHookReceiver0;
        address collateralHookReceiver0;
        address debtHookReceiver0;
        address token1;
        address ltvOracle1;
        address ltOracle1;
        address interestRateModel1;
        uint64 maxLtv1;
        uint64 lt1;
        uint64 liquidationFee1;
        bool borrowable1;
        address protectedHookReceiver1;
        address collateralHookReceiver1;
        address debtHookReceiver1;
    }

    struct ConfigData {
        uint256 daoFee;
        uint256 deployerFee;
        address silo0;
        address token0;
        address protectedShareToken0;
        address collateralShareToken0;
        address debtShareToken0;
        address ltvOracle0;
        address ltOracle0;
        address interestRateModel0;
        uint64 maxLtv0;
        uint64 lt0;
        uint64 liquidationFee0;
        bool borrowable0;
        address silo1;
        address token1;
        address protectedShareToken1;
        address collateralShareToken1;
        address debtShareToken1;
        address ltvOracle1;
        address ltOracle1;
        address interestRateModel1;
        uint64 maxLtv1;
        uint64 lt1;
        uint64 liquidationFee1;
        bool borrowable1;
    }

    struct SmallConfigData {
        uint256 daoFee;
        uint256 deployerFee;
        address token0;
        address protectedShareToken0;
        address collateralShareToken0;
        address debtShareToken0;
        address interestRateModel0;
        address token1;
        address protectedShareToken1;
        address collateralShareToken1;
        address debtShareToken1;
        address interestRateModel1;
    }

    error WrongSilo();

    // solhint-disable func-name-mixedcase

    function SILO_ID() external view returns (uint256);

    function getAssetForSilo(address _silo) external view returns (address asset);
    function getConfig() external view returns (ConfigData memory);
    function getSmallConfigWithAsset(address _silo)
        external
        view
        returns (SmallConfigData memory configData, address asset);
    function getConfigWithAsset(address silo) external view returns (ConfigData memory, address);
}
