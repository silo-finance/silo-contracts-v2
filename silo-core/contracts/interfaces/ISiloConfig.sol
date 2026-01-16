// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISilo} from "./ISilo.sol";
import {ICrossReentrancyGuard} from "./ICrossReentrancyGuard.sol";

interface ISiloConfig is ICrossReentrancyGuard {
    struct InitData {
        /// @notice Can be address zero if deployer fees are not to be collected. If deployer address is zero then
        /// deployer fee must be zero as well. Deployer will be minted an NFT that gives the right to claim deployer
        /// fees. NFT can be transferred with the right to claim.
        address deployer;

        /// @notice Address of the hook receiver called on every before/after action on Silo. Hook contract also
        /// implements liquidation logic and veSilo gauge connection.
        address hookReceiver;

        /// @notice Deployer's fee in 18 decimals points. Deployer will earn this fee based on the interest earned
        /// by the Silo. Max deployer fee is set by the DAO. At deployment it is 15%.
        uint256 deployerFee;

        /// @notice DAO's fee in 18 decimals points. DAO will earn this fee based on the interest earned
        /// by the Silo. Acceptable fee range fee is set by the DAO. Default at deployment is 5% - 50%.
        uint256 daoFee;

        /// @notice Address of the first token
        address token0;

        /// @notice Address of the solvency oracle. Solvency oracle is used to calculate LTV when deciding if borrower
        /// is solvent or should be liquidated. Solvency oracle is optional and if not set price of 1 will be assumed.
        address solvencyOracle0;

        /// @notice Address of the maxLtv oracle. Max LTV oracle is used to calculate LTV when deciding if borrower
        /// can borrow given amount of assets. Max LTV oracle is optional and if not set it defaults to solvency
        /// oracle. If neither is set price of 1 will be assumed.
        address maxLtvOracle0;

        /// @notice Address of the interest rate model
        address interestRateModel0;

        /// @notice Maximum LTV for first token. maxLTV is in 18 decimals points and is used to determine, if borrower
        /// can borrow given amount of assets. MaxLtv is in 18 decimals points. MaxLtv must be lower or equal to LT.
        uint256 maxLtv0;

        /// @notice Liquidation threshold for first token. LT is used to calculate solvency. LT is in 18 decimals
        /// points. LT must not be lower than maxLTV.
        uint256 lt0;

        /// @notice minimal acceptable LTV after liquidation, in 18 decimals points
        uint256 liquidationTargetLtv0;

        /// @notice Liquidation fee for the first token in 18 decimals points. Liquidation fee is what liquidator earns
        /// for repaying insolvent loan.
        uint256 liquidationFee0;

        /// @notice Flashloan fee sets the cost of taking a flashloan in 18 decimals points
        uint256 flashloanFee0;

        /// @notice Indicates if a beforeQuote on oracle contract should be called before quoting price
        bool callBeforeQuote0;

        /// @notice Address of the second token
        address token1;

        /// @notice Address of the solvency oracle. Solvency oracle is used to calculate LTV when deciding if borrower
        /// is solvent or should be liquidated. Solvency oracle is optional and if not set price of 1 will be assumed.
        address solvencyOracle1;

        /// @notice Address of the maxLtv oracle. Max LTV oracle is used to calculate LTV when deciding if borrower
        /// can borrow given amount of assets. Max LTV oracle is optional and if not set it defaults to solvency
        /// oracle. If neither is set price of 1 will be assumed.
        address maxLtvOracle1;

        /// @notice Address of the interest rate model
        address interestRateModel1;

        /// @notice Maximum LTV for first token. maxLTV is in 18 decimals points and is used to determine,
        /// if borrower can borrow given amount of assets. maxLtv is in 18 decimals points
        uint256 maxLtv1;

        /// @notice Liquidation threshold for first token. LT is used to calculate solvency. LT is in 18 decimals points
        uint256 lt1;

        /// @notice minimal acceptable LTV after liquidation, in 18 decimals points
        uint256 liquidationTargetLtv1;

        /// @notice Liquidation fee is what liquidator earns for repaying insolvent loan.
        uint256 liquidationFee1;

        /// @notice Flashloan fee sets the cost of taking a flashloan in 18 decimals points
        uint256 flashloanFee1;

        /// @notice Indicates if a beforeQuote on oracle contract should be called before quoting price
        bool callBeforeQuote1;
    }

    struct ConfigData {
        uint256 daoFee;
        uint256 deployerFee;
        address silo;
        address token;
        address collateralShareToken;
        address debtShareToken;
        address solvencyOracle;
        address maxLtvOracle;
        address interestRateModel;
        uint256 maxLtv;
        uint256 lt;
        uint256 liquidationTargetLtv;
        uint256 liquidationFee;
        uint256 flashloanFee;
        address hookReceiver;
        bool callBeforeQuote;
    }

    struct DepositConfig {
        address silo;
        address token;
        address collateralShareToken;
        uint256 daoFee;
        uint256 deployerFee;
        address interestRateModel;
    }

    error OnlySilo();
    error OnlySiloOrTokenOrHookReceiver();
    error WrongSilo();
    error OnlyDebtShareToken();
    error DebtExistInOtherSilo();
    error FeeTooHigh();
    error Deprecated();

    /// @notice Accrue interest for the silo
    /// @param _silo silo for which accrue interest
    function accrueInterestForSilo(address _silo) external;

    /// @notice Accrue interest for both silos (SILO_0 and SILO_1 in a config)
    function accrueInterestForBothSilos() external;

    /// @notice Retrieves the silo ID
    /// @dev Each silo is assigned a unique ID. ERC-721 token is minted with identical ID to deployer.
    /// An owner of that token receives the deployer fees.
    /// @return siloId The ID of the silo
    function SILO_ID() external view returns (uint256 siloId); // solhint-disable-line func-name-mixedcase

    /// @notice Retrieves the addresses of the two silos
    /// @return silo0 The address of the first silo
    /// @return silo1 The address of the second silo
    function getSilos() external view returns (address silo0, address silo1);

    /// @notice Retrieves the asset associated with a specific silo
    /// @dev This function reverts for incorrect silo address input
    /// @param _silo The address of the silo for which the associated asset is being retrieved
    /// @return asset The address of the asset associated with the specified silo
    function getAssetForSilo(address _silo) external view returns (address asset);

    /// @notice Retrieves configuration data for both silos. First config is for the silo that is asking for configs.
    /// @param borrower borrower address for which debtConfig will be returned
    /// @return collateralConfig The configuration data for collateral silo (empty if there is no debt).
    /// @return debtConfig The configuration data for debt silo (empty if there is no debt).
    function getConfigsForSolvency(address borrower)
        external
        view
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig);

    /// @notice Retrieves configuration data for a specific silo
    /// @dev This function reverts for incorrect silo address input.
    /// @param _silo The address of the silo for which configuration data is being retrieved
    /// @return config The configuration data for the specified silo
    function getConfig(address _silo) external view returns (ConfigData memory config);

    /// @notice Retrieves configuration data for a specific silo for withdraw fn.
    /// @dev This function reverts for incorrect silo address input.
    /// @param _silo The address of the silo for which configuration data is being retrieved
    /// @return depositConfig The configuration data for the specified silo (always config for `_silo`)
    /// @return collateralConfig The configuration data for the collateral silo (empty if there is no debt)
    /// @return debtConfig The configuration data for the debt silo (empty if there is no debt)
    function getConfigsForWithdraw(address _silo, address _borrower) external view returns (
        DepositConfig memory depositConfig,
        ConfigData memory collateralConfig,
        ConfigData memory debtConfig
    );

    /// @notice Retrieves configuration data for a specific silo for borrow fn.
    /// @dev This function reverts for incorrect silo address input.
    /// @param _debtSilo The address of the silo for which configuration data is being retrieved
    /// @return collateralConfig The configuration data for the collateral silo (always other than `_debtSilo`)
    /// @return debtConfig The configuration data for the debt silo (always config for `_debtSilo`)
    function getConfigsForBorrow(address _debtSilo)
        external
        view
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig);

    /// @notice Retrieves fee-related information for a specific silo
    /// @dev This function reverts for incorrect silo address input
    /// @param _silo The address of the silo for which fee-related information is being retrieved.
    /// @return daoFee The DAO fee percentage in 18 decimals points.
    /// @return deployerFee The deployer fee percentage in 18 decimals points.
    /// @return flashloanFee The flashloan fee percentage in 18 decimals points.
    /// @return asset The address of the asset associated with the specified silo.
    function getFeesWithAsset(address _silo)
        external
        view
        returns (uint256 daoFee, uint256 deployerFee, uint256 flashloanFee, address asset);

    /// @notice Retrieves share tokens associated with a specific silo
    /// @dev This function reverts for incorrect silo address input
    /// @param _silo The address of the silo for which share tokens are being retrieved
    /// @return collateralShareToken The address of the collateral share token
    /// @return debtShareToken The address of the debt share token
    function getShareTokens(address _silo)
        external
        view
        returns (address collateralShareToken, address debtShareToken);

    /// @notice Retrieves the share token and the silo token associated with a specific silo
    /// @param _silo The address of the silo for which the share token and silo token are being retrieved
    /// @return shareToken The address of the share token (collateral)
    /// @return asset The address of the silo token
    function getCollateralShareTokenAndAsset(address _silo)
        external
        view
        returns (address shareToken, address asset);

    /// @notice Retrieves the share token and the silo token associated with a specific silo
    /// @param _silo The address of the silo for which the share token and silo token are being retrieved
    /// @return shareToken The address of the share token (debt)
    /// @return asset The address of the silo token
    function getDebtShareTokenAndAsset(address _silo)
        external
        view
        returns (address shareToken, address asset);
}
