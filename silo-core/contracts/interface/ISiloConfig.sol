// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface ISiloConfig {
    struct ConfigData {
        address token0;
        address protectedCollateralShareToken0;
        address collateralShareToken0;
        address debtShareToken0;
        address ltvOracle0;
        address ltOracle0;
        address interestRateModel0;
        uint64 maxLtv0;
        uint64 lt0;
        bool borrowable0;
        address token1;
        address protectedCollateralShareToken1;
        address collateralShareToken1;
        address debtShareToken1;
        address ltvOracle1;
        address ltOracle1;
        address interestRateModel1;
        uint64 maxLtv1;
        uint64 lt1;
        bool borrowable1;
    }

    error SameAsset();
    error InvalidIrm();
    error InvalidMaxLtv();
    error NonBorrowableSilo();
    error InvalidShareTokens();

    function SILO_ID() external view returns (uint256);

    // TOKEN #0

    function TOKEN0() external view returns (address);
    function PROTECTED_COLLATERAL_SHARE_TOKEN0() external view returns (address);
    function COLLATERAL_SHARE_TOKEN0() external view returns (address);
    function DEBT_SHARE_TOKEN0() external view returns (address);
    function LTV_ORACLE0() external view returns (address);
    function LT_ORACLE0() external view returns (address);
    function INTEREST_RATE_MODEL0() external view returns (address);
    function MAX_LTV0() external view returns (uint64);
    function LT0() external view returns (uint64);
    function BORROWABLE0() external view returns (bool);

    // TOKEN #1

    function TOKEN1() external view returns (address);
    function PROTECTED_COLLATERAL_SHARE_TOKEN1() external view returns (address);
    function COLLATERAL_SHARE_TOKEN1() external view returns (address);
    function DEBT_SHARE_TOKEN1() external view returns (address);
    function LTV_ORACLE1() external view returns (address);
    function LT_ORACLE1() external view returns (address);
    function INTEREST_RATE_MODEL1() external view returns (address);
    function MAX_LTV1() external view returns (uint64);
    function LT1() external view returns (uint64);
    function BORROWABLE1() external view returns (bool);

    function getConfig() external view returns (ConfigData memory);
}
