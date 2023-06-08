// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.17;

interface ISiloConfig {
    struct ConfigData {
        address token0;
        address protectedCollateralShareToken0;
        address collateralShareToken0;
        address debtShareToken0;
        address ltvOracle0;
        address ltOracle0;
        address interestRateModel0;
        uint256 maxLtv0;
        uint256 lt0;
        bool borrowable0;
        address token1;
        address protectedCollateralShareToken1;
        address collateralShareToken1;
        address debtShareToken1;
        address ltvOracle1;
        address ltOracle1;
        address interestRateModel1;
        uint256 maxLtv1;
        uint256 lt1;
        bool borrowable1;
    }

    function SILO_ID() external view returns (uint256);

    /**
     * TOKEN #0
     */

    function token0() external view returns (address);
    function protectedCollateralShareToken0() external view returns (address);
    function collateralShareToken0() external view returns (address);
    function debtShareToken0() external view returns (address);
    function ltvOracle0() external view returns (address);
    function ltOracle0() external view returns (address);
    function interestRateModel0() external view returns (address);
    function maxLtv0() external view returns (uint256);
    function lt0() external view returns (uint256);
    function borrowable0() external view returns (bool);

    /**
     * TOKEN #1
     */

    function token1() external view returns (address);
    function protectedCollateralShareToken1() external view returns (address);
    function collateralShareToken1() external view returns (address);
    function debtShareToken1() external view returns (address);
    function ltvOracle1() external view returns (address);
    function ltOracle1() external view returns (address);
    function interestRateModel1() external view returns (address);
    function maxLtv1() external view returns (uint256);
    function lt1() external view returns (uint256);
    function borrowable1() external view returns (bool);

    function getConfig() external view returns (ConfigData memory);
}
