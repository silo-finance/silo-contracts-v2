// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

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

        /// @notice The address of contract that will be responsible for executing liquidations
        address liquidationModule;

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

        /// @notice Address of the hook receiver called on every share token transfer for protected (non-borrowable)
        /// collateral
        address protectedHookReceiver0;

        /// @notice Address of the hook receiver called on every share token transfer for collateral
        address collateralHookReceiver0;

        /// @notice Address of the hook receiver called on every share token transfer for debt
        address debtHookReceiver0;

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

        /// @notice Address of the hook receiver called on every share token transfer for protected (non-borrowable)
        /// collateral
        address protectedHookReceiver1;

        /// @notice Address of the hook receiver called on every share token transfer for collateral
        address collateralHookReceiver1;

        /// @notice Address of the hook receiver called on every share token transfer for debt
        address debtHookReceiver1;
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
        address liquidationModule;
        bool callBeforeQuote;
    }

    error OnlySilo();
    error OnlySiloOrLiquidationModule();
    error OnlySiloOrDebtShareToken();
    error WrongSilo();
    error OnlyDebtShareToken();
    error DebtExistInOtherSilo();
    error NoDebt();
    error CollateralTypeDidNotChanged();

    error XReentrantCall();

    /// @dev can be called only by silo, it opens debt for `_borrower`
    /// @param _borrower borrower address
    /// @param _sameAsset TRUE if `_borrower` open debt in the same token
    /// @return collateralConfig The configuration data for collateral silo.
    /// @return debtConfig The configuration data for debt silo.
    /// @return debtInfo details about `borrower` debt
    function openDebt(address _borrower, bool _sameAsset)
        external
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo);

    /// @dev should be called on debt transfer, it opens debt if `_to` address don't have one
    /// @param _sender sender address
    /// @param _recipient recipient address
    function onDebtTransfer(address _sender, address _recipient) external;

    /// @dev must be called when `_borrower` repay all debt, there is no restriction from which silo call will be done
    /// @param _borrower borrower address
    function closeDebt(address _borrower) external;

    /// @notice it will change collateral for existing debt, only silo can call it
    /// @return collateralConfig The configuration data for collateral silo.
    /// @return debtConfig The configuration data for debt silo.
    /// @return debtInfo details about `borrower` debt
    function changeCollateralType(address _borrower, bool _sameAsset)
        external
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig, DebtInfo memory debtInfo);


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
    /// @param _method always zero for external usage
    /// @return collateralConfig The configuration data for collateral silo.
    /// @return debtConfig The configuration data for debt silo.
    /// @return debtInfo details about `borrower` debt
    function getConfigs(address _silo, address borrower, uint256 _method)
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

    /// @notice only silo method for cross reentrancy
    function xNonReentrantBefore() external;

    /// @notice only silo method for cross reentrancy
    function xNonReentrantAfter() external;

    /// @notice vew method for checking cross reentrancy flag
    function xReentrancyGuardEntered() external view returns (bool);
}
