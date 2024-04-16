// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IHookReceiver} from "../utils/hook-receivers/interfaces/IHookReceiver.sol";

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

        /// @notice Address of the hook receiver called on every before/after action on Silo0 (with token0)
        address hookReceiver0;

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

        /// @notice Address of the hook receiver called on every before/after action on Silo1 (with token1)
        address hookReceiver1;

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
        address liquidationModule;
        address hookReceiver;
        bool callBeforeQuote;
    }

    struct HooksSetup {
        uint64 silo0HooksBefore;
        uint64 silo0HooksAfter;
        uint64 silo1HooksBefore;
        uint64 silo1HooksAfter;
    }

    error OnlySilo();
    error OnlySiloOrLiquidationModule();
    error OnlyShareToken();
    error OnlySiloOrDebtShareToken();
    error WrongSilo();
    error OnlyDebtShareToken();
    error DebtExistInOtherSilo();
    error NoDebt();
    error CollateralTypeDidNotChanged();

    error CrossReentrantCall();
    error OnlyHookReceiver();

    event HooksUpdated(address silo, uint256 hooksBefore, uint256 hooksAfter);

    /// @notice Method for HookReceiver only to update hooks
    /// If there are two different hookReceivers then each can update only his silo settings.
    /// Other parameters will be ignored.
    /// @param _silo0HooksBefore bitmap for Silo0 hooks before, see Hook.sol
    /// @param _silo0HooksAfter bitmap for Silo0 hooks after, see Hook.sol
    /// @param _silo1HooksBefore bitmap for Silo1 hooks before, see Hook.sol
    /// @param _silo1HooksAfter bitmap for Silo1 hooks after, see Hook.sol
    function updateHooks(
        uint64 _silo0HooksBefore,
        uint64 _silo0HooksAfter,
        uint64 _silo1HooksBefore,
        uint64 _silo1HooksAfter
    ) external;

    /// @dev Can be called only by silo, share token or liquidation module
    /// It will call hook if needed, raise reentrancy guard and return necessary configuration to perform action
    /// @param _silo silo address for which action is called
    /// @param _borrower borrower address
    /// @param _hook bitmap with all action flags, see `Hook.sol`
    /// @param _input encoded input data that will be used for hook call
    /// @return collateralConfig The configuration data for collateral silo.
    /// @return debtConfig The configuration data for debt silo.
    /// @return debtInfo details about `borrower` debt
    function startAction(address _silo, address _borrower, uint256 _hook, bytes calldata _input)
        external
        returns (
            ConfigData memory collateralConfig,
            ConfigData memory debtConfig,
            DebtInfo memory debtInfo,
            IHookReceiver hookReceiverAfter
        );

    /// @dev should be called on debt transfer, it opens debt if `_to` address don't have one
    /// @param _sender sender address
    /// @param _recipient recipient address
    function onDebtTransfer(address _sender, address _recipient) external;

    /// @dev must be called when `_borrower` repay all debt, there is no restriction from which silo call will be done
    /// @param _borrower borrower address
    function closeDebt(address _borrower) external;

    /// @notice method for manipulating reentrancy flag for leverage
    /// @param _entranceFrom see CrossEntrancy lib for possible values
    function crossLeverageGuard(uint256 _entranceFrom) external;

    /// @notice vew method for checking cross Silo git pushreentrancy flag
    function crossReentrancyGuardEntered() external view returns (bool);

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

    /// @dev it will execute necessary actions at the end eg. disable reentrancy flag
    function finishAction() external;

    function finishAction(address _h, uint256 _hook, bytes calldata _data) external;

}
