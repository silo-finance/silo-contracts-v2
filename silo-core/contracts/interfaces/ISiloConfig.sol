// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IHookReceiver} from "./IHookReceiver.sol";
import {ISilo} from "./ISilo.sol";

interface ISiloConfig {
    struct DebtInfo {
        bool debtPresent;
        bool sameAsset;
        bool debtInSilo0;
        bool debtInThisSilo; // at-hoc when getting configs
    }

    struct InitData {
        /// @notice The address of the deployer of the Silo
        address deployer;

        /// @notice Address of the hook receiver called on every before/after action on Silo
        address hookReceiver;

        /// @notice Deployer's fee in 18 decimals points. Deployer will earn this fee based on the interest earned by
        /// the Silo.
        uint256 deployerFee;

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

        /// @notice Address of the interest rate model configuration. Configuration is a separately deployed contract
        /// with immutable config that can be resued between multiple IRMs (Interest Rate Models).
        address interestRateModelConfig0;

        /// @notice Maximum LTV for first token. maxLTV is in 18 decimals points and is used to determine,
        /// if borrower can borrow given amount of assets. MaxLtv is in 18 decimals points
        uint256 maxLtv0;

        /// @notice Liquidation threshold for first token. LT is used to calculate solvency. LT is in 18 decimals points
        uint256 lt0;

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

        /// @notice Address of the interest rate model configuration. Configuration is a separately deployed contract
        /// with immutable config that can be reused between multiple IRMs (Interest Rate Models).
        address interestRateModelConfig1;

        /// @notice Maximum LTV for first token. maxLTV is in 18 decimals points and is used to determine,
        /// if borrower can borrow given amount of assets. maxLtv is in 18 decimals points
        uint256 maxLtv1;

        /// @notice Liquidation threshold for first token. LT is used to calculate solvency. LT is in 18 decimals points
        uint256 lt1;

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
        address hookReceiver;
        bool callBeforeQuote;
    }

    error OnlySilo();
    error OnlySiloOrHookReceiver();
    error OnlyShareToken();
    error OnlySiloOrDebtShareToken();
    error WrongSilo();
    error OnlyDebtShareToken();
    error DebtExistInOtherSilo();
    error NoDebt();
    error CollateralTypeDidNotChanged();
    error CrossReentrantCall();
    error CrossReentrancyNotActive();
    error InvalidConfigOrder();
    error FeeTooHigh();

    /// @dev It should be called on debt transfer. It sets collateral silo if the `_to` address doesn't have one
    /// @param _sender sender address
    /// @param _recipient recipient address
    function onDebtTransfer(address _sender, address _recipient) external;

    /// @notice only silo method for cross Silo reentrancy
    function crossNonReentrantBefore() external;

    /// @notice only silo method for cross Silo reentrancy
    function crossNonReentrantAfter() external;

    /// @notice Set collateral silo
    /// @param _borrower borrower address
    /// @param _sameAsset true if `_borrower` operates on the same asset
    function setCollateralSilo(address _borrower, bool _sameAsset) external;

    function accrueInterestAndGetConfig(address _silo) external returns (ConfigData memory);

    function accrueInterestAndGetConfigs(address _silo, address _borrower, uint256 _action)
        external
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo);

    function accrueInterestAndGetConfigOptimised(
        uint256 _action,
        ISilo.CollateralType _collateralType
    ) external returns (address shareToken, address asset);

    /// @notice view method for checking cross Silo reentrancy flag
    /// @return entered true if the reentrancy guard is currently set to "entered", which indicates there is a
    /// `nonReentrant` function in the call stack.
    /// @return status precise status of reentrancy, see CrossEntrancy.sol for possible values
    function crossReentrantStatus() external view returns (bool entered, uint256 status);

    /// @notice Checks if the borrower has debt in other silo by checking the debt share token balance
    /// @param _debtShareToken The address of the debt share token (we will check the opposite silo)
    /// @param _borrower The address of the borrower
    /// @return hasDebt true if the borrower has debt in the other silo
    function hasDebtInOtherSilo(address _debtShareToken, address _borrower) external view returns (bool hasDebt);

    // solhint-disable-next-line func-name-mixedcase
    function SILO_ID() external view returns (uint256);

    /// @notice Retrieves the addresses of the two silos
    /// @return silo0 The address of the first silo
    /// @return silo1 The address of the second silo
    function getSilos() external view returns (address, address);

    /// @notice Retrieves the asset associated with a specific silo
    /// @dev This function reverts for incorrect silo address input
    /// @param _silo The address of the silo for which the associated asset is being retrieved
    /// @return asset The address of the asset associated with the specified silo
    function getAssetForSilo(address _silo) external view returns (address asset);

    /// @notice Retrieves configuration data for both silos. First config is for the silo that is asking for configs.
    /// @dev This function reverts for incorrect silo address input.
    /// @param _silo The address of the silo for which configuration data is being retrieved. Config for this silo will
    /// be at index 0.
    /// @param borrower borrower address for which `debtInfo` will be returned
    /// @param _action hook flag that will determine action
    /// @return collateralConfig The configuration data for collateral silo.
    /// @return debtConfig The configuration data for debt silo.
    /// @return debtInfo details about `borrower` debt
    function getConfigs(address _silo, address borrower, uint256 _action)
        external
        view
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo);

    /// @notice Retrieves configuration data for a specific silo
    /// @dev This function reverts for incorrect silo address input.
    /// @param _silo The address of the silo for which configuration data is being retrieved
    /// @return configData The configuration data for the specified silo
    function getConfig(address _silo) external view returns (ConfigData memory);

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
    /// @return protectedShareToken The address of the protected (non-borrowable) share token
    /// @return collateralShareToken The address of the collateral share token
    /// @return debtShareToken The address of the debt share token
    function getShareTokens(address _silo)
        external
        view
        returns (address protectedShareToken, address collateralShareToken, address debtShareToken);
}
