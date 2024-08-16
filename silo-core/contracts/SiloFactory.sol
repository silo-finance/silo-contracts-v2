// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {Initializable} from "openzeppelin5-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {ERC721} from "openzeppelin5/token/ERC721/ERC721.sol";

import {IShareToken} from "./interfaces/IShareToken.sol";
import {ISiloFactory} from "./interfaces/ISiloFactory.sol";
import {ISiloConfig, SiloConfig} from "./SiloConfig.sol";
import {ISilo, Silo} from "./Silo.sol";
import {Creator} from "./utils/Creator.sol";
import {Hook} from "./lib/Hook.sol";

contract SiloFactory is ISiloFactory, ERC721, Ownable2Step, Creator {
    /// @dev max fee is 40%, 1e18 == 100%
    uint256 public constant MAX_FEE = 0.4e18;

    /// @dev max percent is 1e18 == 100%
    uint256 public constant MAX_PERCENT = 1e18;

    uint256 private _siloId;

    /// @dev denominated in 18 decimals points. 1e18 == 100%.
    uint256 public daoFee;
    /// @dev denominated in 18 decimals points. 1e18 == 100%.
    uint256 public maxDeployerFee;
    /// @dev denominated in 18 decimals points. 1e18 == 100%.
    uint256 public maxFlashloanFee;
    /// @dev denominated in 18 decimals points. 1e18 == 100%.
    uint256 public maxLiquidationFee;

    address public daoFeeReceiver;

    address public siloImpl;
    address public shareCollateralTokenImpl;
    address public shareDebtTokenImpl;

    mapping(uint256 id => address[2] silos) private _idToSilos;
    mapping(address silo => uint256 id) public siloToId;

    constructor() ERC721("Silo Finance Fee Receiver", "feeSILO") Ownable(msg.sender) {}

    /// @dev SiloFactory is not clonable contract. initialize() method is here only because we have
    /// circular dependency: SiloFactory needs to know Silo address and Silo needs to know factory address.
    /// Because of that, `initialize()` will be always executed on deployed factory, so there is no need for
    /// disabling initializer by calling `_disableInitializers()` in constructor, especially that only creator can init.
    function initialize(
        address _siloImpl,
        address _shareCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _daoFee,
        address _daoFeeReceiver
    ) external virtual onlyCreator {
        if (_siloId != 0) revert InvalidInitialization();

        // start IDs from 1
        _siloId = 1;

        if (_siloImpl == address(0) || _shareCollateralTokenImpl == address(0) || _shareDebtTokenImpl == address(0)) {
            revert ZeroAddress();
        }

        siloImpl = _siloImpl;
        shareCollateralTokenImpl = _shareCollateralTokenImpl;
        shareDebtTokenImpl = _shareDebtTokenImpl;

        uint256 _maxDeployerFee = 0.15e18; // 15% max deployer fee
        uint256 _newMaxFlashloanFee = 0.15e18; // 15% max flashloan fee
        uint256 _newMaxLiquidationFee = 0.30e18; // 30% max liquidation fee

        _setDaoFee(_daoFee);
        _setDaoFeeReceiver(_daoFeeReceiver);

        _setMaxDeployerFee(_maxDeployerFee);
        _setMaxFlashloanFee(_newMaxFlashloanFee);
        _setMaxLiquidationFee(_newMaxLiquidationFee);
    }

    /// @dev share tokens in _configData are overridden so can be set to address(0). Sanity data validation
    ///      is done by SiloConfig.
    /// @param _initData silo initialization data
    function createSilo(ISiloConfig.InitData memory _initData) external virtual returns (ISiloConfig siloConfig) {
        validateSiloInitData(_initData);
        (ISiloConfig.ConfigData memory configData0, ISiloConfig.ConfigData memory configData1) = _copyConfig(_initData);

        uint256 nextSiloId = _siloId;

        if (nextSiloId == 0) revert Uninitialized();

        // safe to uncheck, because we will not create 2 ** 256 of silos in a lifetime
        unchecked { _siloId++; }

        configData0.daoFee = daoFee;
        configData1.daoFee = daoFee;

        _cloneShareTokens(configData0, configData1);

        configData0.silo = Clones.clone(siloImpl);
        configData1.silo = Clones.clone(siloImpl);

        siloConfig = ISiloConfig(address(new SiloConfig(nextSiloId, configData0, configData1)));

        ISilo(configData0.silo).initialize(siloConfig, _initData.interestRateModelConfig0);
        ISilo(configData1.silo).initialize(siloConfig, _initData.interestRateModelConfig1);

        _initializeShareTokens(configData0, configData1);

        ISilo(configData0.silo).updateHooks();
        ISilo(configData1.silo).updateHooks();

        siloToId[configData0.silo] = nextSiloId;
        siloToId[configData1.silo] = nextSiloId;
        _idToSilos[nextSiloId] = [configData0.silo, configData1.silo];

        if (_initData.deployer != address(0)) {
            _mint(_initData.deployer, nextSiloId);
        }

        emit NewSilo(configData0.token, configData1.token, configData0.silo, configData1.silo, address(siloConfig));
    }

    function setDaoFee(uint256 _newDaoFee) external virtual onlyOwner {
        _setDaoFee(_newDaoFee);
    }

    function setMaxDeployerFee(uint256 _newMaxDeployerFee) external virtual onlyOwner {
        _setMaxDeployerFee(_newMaxDeployerFee);
    }

    function setMaxFlashloanFee(uint256 _newMaxFlashloanFee) external virtual onlyOwner {
        _setMaxFlashloanFee(_newMaxFlashloanFee);
    }

    function setMaxLiquidationFee(uint256 _newMaxLiquidationFee) external virtual onlyOwner {
        _setMaxLiquidationFee(_newMaxLiquidationFee);
    }

    function setDaoFeeReceiver(address _newDaoFeeReceiver) external virtual onlyOwner {
        _setDaoFeeReceiver(_newDaoFeeReceiver);
    }

    function isSilo(address _silo) external view virtual returns (bool) {
        return siloToId[_silo] != 0;
    }

    function idToSilos(uint256 _id) external view virtual returns (address[2] memory silos) {
        silos = _idToSilos[_id];
    }

    function getNextSiloId() external view virtual returns (uint256) {
        return _siloId;
    }

    function getFeeReceivers(address _silo) external view virtual returns (address dao, address deployer) {
        return (daoFeeReceiver, _ownerOf(siloToId[_silo]));
    }

    function validateSiloInitData(ISiloConfig.InitData memory _initData) public view virtual returns (bool) {
        // solhint-disable-previous-line code-complexity
        if (_initData.hookReceiver == address(0)) revert MissingHookReceiver();

        if (_initData.token0 == address(0)) revert EmptyToken0();
        if (_initData.token1 == address(0)) revert EmptyToken1();

        if (_initData.token0 == _initData.token1) revert SameAsset();
        if (_initData.maxLtv0 == 0 && _initData.maxLtv1 == 0) revert InvalidMaxLtv();
        if (_initData.maxLtv0 > _initData.lt0) revert InvalidMaxLtv();
        if (_initData.maxLtv1 > _initData.lt1) revert InvalidMaxLtv();
        if (_initData.lt0 > MAX_PERCENT || _initData.lt1 > MAX_PERCENT) revert InvalidLt();

        if (_initData.maxLtvOracle0 != address(0) && _initData.solvencyOracle0 == address(0)) {
            revert OracleMisconfiguration();
        }

        if (_initData.callBeforeQuote0 && _initData.solvencyOracle0 == address(0)) revert BeforeCall();

        if (_initData.maxLtvOracle1 != address(0) && _initData.solvencyOracle1 == address(0)) {
            revert OracleMisconfiguration();
        }

        if (_initData.callBeforeQuote1 && _initData.solvencyOracle1 == address(0)) revert BeforeCall();
        if (_initData.deployerFee > 0 && _initData.deployer == address(0)) revert InvalidDeployer();
        if (_initData.deployerFee > maxDeployerFee) revert MaxDeployerFee();
        if (_initData.flashloanFee0 > maxFlashloanFee) revert MaxFlashloanFee();
        if (_initData.flashloanFee1 > maxFlashloanFee) revert MaxFlashloanFee();
        if (_initData.liquidationFee0 > maxLiquidationFee) revert MaxLiquidationFee();
        if (_initData.liquidationFee1 > maxLiquidationFee) revert MaxLiquidationFee();

        if (_initData.interestRateModelConfig0 == address(0) || _initData.interestRateModelConfig1 == address(0)) {
            revert InvalidIrmConfig();
        }

        if (_initData.interestRateModel0 == address(0) || _initData.interestRateModel1 == address(0)) {
            revert InvalidIrm();
        }

        return true;
    }

    function _setDaoFee(uint256 _newDaoFee) internal virtual {
        if (_newDaoFee > MAX_FEE) revert MaxFee();

        daoFee = _newDaoFee;

        emit DaoFeeChanged(_newDaoFee);
    }

    function _setMaxDeployerFee(uint256 _newMaxDeployerFee) internal virtual {
        if (_newMaxDeployerFee >= MAX_FEE) revert MaxFee();

        maxDeployerFee = _newMaxDeployerFee;

        emit MaxDeployerFeeChanged(_newMaxDeployerFee);
    }

    function _setMaxFlashloanFee(uint256 _newMaxFlashloanFee) internal virtual {
        if (_newMaxFlashloanFee >= MAX_FEE) revert MaxFee();

        maxFlashloanFee = _newMaxFlashloanFee;

        emit MaxFlashloanFeeChanged(_newMaxFlashloanFee);
    }

    function _setMaxLiquidationFee(uint256 _newMaxLiquidationFee) internal virtual {
        if (_newMaxLiquidationFee >= MAX_FEE) revert MaxFee();

        maxLiquidationFee = _newMaxLiquidationFee;

        emit MaxLiquidationFeeChanged(_newMaxLiquidationFee);
    }

    function _setDaoFeeReceiver(address _newDaoFeeReceiver) internal virtual {
        if (_newDaoFeeReceiver == address(0)) revert ZeroAddress();

        daoFeeReceiver = _newDaoFeeReceiver;

        emit DaoFeeReceiverChanged(_newDaoFeeReceiver);
    }

    function _cloneShareTokens(
        ISiloConfig.ConfigData memory configData0,
        ISiloConfig.ConfigData memory configData1
    ) internal virtual {
        configData0.protectedShareToken = Clones.clone(shareCollateralTokenImpl);
        configData0.collateralShareToken = configData0.silo;
        configData0.debtShareToken = Clones.clone(shareDebtTokenImpl);
        configData1.protectedShareToken = Clones.clone(shareCollateralTokenImpl);
        configData1.collateralShareToken = configData1.silo;
        configData1.debtShareToken = Clones.clone(shareDebtTokenImpl);
    }

    function _initializeShareTokens(
        ISiloConfig.ConfigData memory configData0,
        ISiloConfig.ConfigData memory configData1
    ) internal virtual {
        uint24 protectedTokenType = uint24(Hook.PROTECTED_TOKEN);
        uint24 collateralTokenType = uint24(Hook.COLLATERAL_TOKEN);
        uint24 debtTokenType = uint24(Hook.DEBT_TOKEN);

        // initialize configData0
        ISilo silo0 = ISilo(configData0.silo);
        address hookReceiver0 = configData0.hookReceiver;

        IShareToken(configData0.protectedShareToken).initialize(silo0, hookReceiver0, protectedTokenType);
        IShareToken(configData0.debtShareToken).initialize(silo0, hookReceiver0, debtTokenType);

        // initialize configData1
        ISilo silo1 = ISilo(configData1.silo);
        address hookReceiver1 = configData1.hookReceiver;

        IShareToken(configData1.protectedShareToken).initialize(silo1, hookReceiver1, protectedTokenType);
        IShareToken(configData1.debtShareToken).initialize(silo1, hookReceiver1, debtTokenType);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "//app.silo.finance/silo/";
    }

    function _copyConfig(ISiloConfig.InitData memory _initData)
        internal
        pure
        virtual
        returns (ISiloConfig.ConfigData memory configData0, ISiloConfig.ConfigData memory configData1)
    {
        configData0.hookReceiver = _initData.hookReceiver;
        configData0.token = _initData.token0;
        configData0.solvencyOracle = _initData.solvencyOracle0;
        // If maxLtv oracle is not set, fallback to solvency oracle
        configData0.maxLtvOracle = _initData.maxLtvOracle0 == address(0)
            ? _initData.solvencyOracle0
            : _initData.maxLtvOracle0;
        configData0.interestRateModel = _initData.interestRateModel0;
        configData0.maxLtv = _initData.maxLtv0;
        configData0.lt = _initData.lt0;
        configData0.deployerFee = _initData.deployerFee;
        configData0.liquidationFee = _initData.liquidationFee0;
        configData0.flashloanFee = _initData.flashloanFee0;
        configData0.callBeforeQuote = _initData.callBeforeQuote0 && configData0.maxLtvOracle != address(0);

        configData1.hookReceiver = _initData.hookReceiver;
        configData1.token = _initData.token1;
        configData1.solvencyOracle = _initData.solvencyOracle1;
        // If maxLtv oracle is not set, fallback to solvency oracle
        configData1.maxLtvOracle = _initData.maxLtvOracle1 == address(0)
            ? _initData.solvencyOracle1
            : _initData.maxLtvOracle1;
        configData1.interestRateModel = _initData.interestRateModel1;
        configData1.maxLtv = _initData.maxLtv1;
        configData1.lt = _initData.lt1;
        configData1.deployerFee = _initData.deployerFee;
        configData1.liquidationFee = _initData.liquidationFee1;
        configData1.flashloanFee = _initData.flashloanFee1;
        configData1.callBeforeQuote = _initData.callBeforeQuote1 && configData1.maxLtvOracle != address(0);
    }
}
