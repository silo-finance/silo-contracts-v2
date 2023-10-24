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
        bool callBeforeQuote0;
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
        bool callBeforeQuote1;
        address protectedHookReceiver1;
        address collateralHookReceiver1;
        address debtHookReceiver1;
    }

    struct ConfigData {
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
        uint256 maxLtv;
        uint256 lt;
        uint256 liquidationFee;
        uint256 flashloanFee;
        bool callBeforeQuote;
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
