// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IERC721} from "openzeppelin5/interfaces/IERC721.sol";
import {ISiloConfig} from "./ISiloConfig.sol";

interface ISiloFactory is IERC721 {
    /// @notice Emitted on the creation of a Silo.
    /// @param token0 Address of the first Silo token.
    /// @param token1 Address of the second Silo token.
    /// @param silo0 Address of the first Silo.
    /// @param silo1 Address of the second Silo.
    /// @param siloConfig Address of the SiloConfig.
    event NewSilo(address indexed token0, address indexed token1, address silo0, address silo1, address siloConfig);

    /// @notice Emitted on the update of DAO fee.
    /// @param daoFee Value of the new DAO fee.
    event DaoFeeChanged(uint256 daoFee);

    /// @notice Emitted on the update of max deployer fee.
    /// @param maxDeployerFee Value of the new max deployer fee.
    event MaxDeployerFeeChanged(uint256 maxDeployerFee);

    /// @notice Emitted on the update of max flashloan fee.
    /// @param maxFlashloanFee Value of the new max flashloan fee.
    event MaxFlashloanFeeChanged(uint256 maxFlashloanFee);

    /// @notice Emitted on the update of max liquidation fee.
    /// @param maxLiquidationFee Value of the new max liquidation fee.
    event MaxLiquidationFeeChanged(uint256 maxLiquidationFee);

    /// @notice Emitted on the change of DAO fee receiver.
    /// @param daoFeeReceiver Address of the new DAO fee receiver.
    event DaoFeeReceiverChanged(address daoFeeReceiver);

    error InvalidInitialization();
    error Uninitialized();
    error MissingHookReceiver();
    error ZeroAddress();
    error EmptyToken0();
    error EmptyToken1();
    error MaxFeeExceeded();
    error SameAsset();
    error InvalidIrm();
    error InvalidMaxLtv();
    error InvalidLt();
    error InvalidDeployer();
    error MaxDeployerFeeExceeded();
    error MaxFlashloanFeeExceeded();
    error MaxLiquidationFeeExceeded();
    error InvalidIrmConfig();
    error InvalidCallBeforeQuote();
    error OracleMisconfiguration();

    /// @notice Initialize SiloFactory contract.
    /// @dev SiloFactory is not clonable contract. initialize() method is here only because we have
    /// circular dependency: SiloFactory needs to know Silo address and Silo needs to know factory address.
    /// Because of that, `initialize()` will be always executed on deployed factory, so there is no need for
    /// disabling initializer by calling `_disableInitializers()` in constructor, especially that only owner can init.
    /// @param _siloImpl Address of the Silo implementation.
    /// @param _shareCollateralTokenImpl Address of the ShareCollateralToken implementation.
    /// @param _shareDebtTokenImpl Address of the ShareDebtToken implementation.
    /// @param _daoFee The accrued interest fee to be taken for the DAO (in 18 decimals points).
    /// @param _daoFeeReceiver The DAO fee receiver address.
    function initialize(
        address _siloImpl,
        address _shareCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _daoFee,
        address _daoFeeReceiver
    ) external;

    /// @notice Create a new Silo.
    /// @param _initData Silo initialization data.
    /// @return siloConfig Config for the created Silo.
    function createSilo(ISiloConfig.InitData memory _initData) external returns (ISiloConfig siloConfig);

    /// @notice NFT ownership represents the deployer fee receiver for the each Silo ID.  After burning, 
    /// the deployer fee is sent to the DAO. Burning doesn't affect Silo's behavior. It is only about fee distribution.
    /// @param _siloIdToBurn silo ID to burn.
    function burn(uint256 _siloIdToBurn) external;

    /// @notice Update the value of DAO fee. Updated value will be used only for a new Silos.
    /// Previously deployed SiloConfigs are immutable.
    /// @param _newDaoFee Value of the new DAO fee.
    function setDaoFee(uint256 _newDaoFee) external;

    /// @notice Set the new DAO fee receiver.
    /// @param _newDaoFeeReceiver Address of the new DAO fee receiver.
    function setDaoFeeReceiver(address _newDaoFeeReceiver) external;

    /// @notice Update the value of max deployer fee. Updated value will be used only for a new Silos max deployer
    /// fee validation. Previously deployed SiloConfigs are immutable.
    /// @param _newMaxDeployerFee Value of the new max deployer fee.
    function setMaxDeployerFee(uint256 _newMaxDeployerFee) external;

    /// @notice Update the value of max flashloan fee. Updated value will be used only for a new Silos max flashloan
    /// fee validation. Previously deployed SiloConfigs are immutable.
    /// @param _newMaxFlashloanFee Value of the new max flashloan fee.
    function setMaxFlashloanFee(uint256 _newMaxFlashloanFee) external;

    /// @notice Update the value of max liquidation fee. Updated value will be used only for a new Silos max
    /// liquidation fee validation. Previously deployed SiloConfigs are immutable.
    /// @param _newMaxLiquidationFee Value of the new max liquidation fee.
    function setMaxLiquidationFee(uint256 _newMaxLiquidationFee) external;
   
    /// @notice Update the base URI.
    /// @param _newBaseURI Value of the new base URI.
    function setBaseURI(string calldata _newBaseURI) external;

    /// @notice DAO fee.
    function daoFee() external view returns (uint256);

    /// @notice Max deployer fee for a new Silos.
    function maxDeployerFee() external view returns (uint256);

    /// @notice Max flashloan fee for a new Silos.
    function maxFlashloanFee() external view returns (uint256);

    /// @notice Max liquidation fee for a new Silos.
    function maxLiquidationFee() external view returns (uint256);

    /// @notice The recipient of DAO fees.
    function daoFeeReceiver() external view returns (address);

    /// @notice Address of Silo implementation.
    function siloImpl() external view returns (address);

    /// @notice Address of ShareProtectedCollateralToken implementation.
    function shareProtectedCollateralTokenImpl() external view returns (address);

    /// @notice Address of ShareDebtToken implementation.
    function shareDebtTokenImpl() external view returns (address);

    /// @notice Get SiloConfig address by Silo id.
    function idToSiloConfig(uint256 _id) external view returns (address);

    /// @notice True if the address is Silo, false otherwise.
    function isSilo(address _silo) external view returns (bool);

    /// @notice Id of a next Silo to be deployed. This is an ID of non-existing Silo outside of createSilo
    /// function call. ID of a first Silo is 1.
    function getNextSiloId() external view returns (uint256);

    /// @notice Get the DAO and deployer fee receivers for a particular Silo address.
    /// @param _silo Silo address.
    /// @return dao DAO fee receiver.
    /// @return deployer Deployer fee receiver.
    function getFeeReceivers(address _silo) external view returns (address dao, address deployer);

    /// @notice Validate InitData for a new Silo. Config will be checked for the fee limits, missing parameters.
    /// @param _initData Silo init data.
    function validateSiloInitData(ISiloConfig.InitData memory _initData) external view returns (bool);
}
