// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Strings} from "openzeppelin5/utils/Strings.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {ERC721} from "openzeppelin5/token/ERC721/ERC721.sol";

import {IShareTokenInitializable} from "./interfaces/IShareTokenInitializable.sol";
import {ISiloFactory} from "./interfaces/ISiloFactory.sol";
import {ISilo} from "./interfaces/ISilo.sol";
import {ISiloConfig, SiloConfig} from "./SiloConfig.sol";
import {Hook} from "./lib/Hook.sol";
import {Views} from "./lib/Views.sol";
import {CloneDeterministic} from "./lib/CloneDeterministic.sol";

contract SiloFactory is ISiloFactory, ERC721, Ownable2Step {
    /// @dev max fee is 50%, 1e18 == 100%
    uint256 public constant MAX_FEE = 0.5e18;

    /// @dev max percent is 1e18 == 100%
    uint256 public constant MAX_PERCENT = 1e18;

    /// @dev dao fee range (min, max) in 18 decimals, 1e18 == 100%
    Range private _daoFeeRange;
    uint256 public maxDeployerFee;
    uint256 public maxFlashloanFee;
    uint256 public maxLiquidationFee;
    address public daoFeeReceiver;

    string public baseURI;

    mapping(uint256 id => address siloConfig) public idToSiloConfig;
    mapping(address silo => bool) public isSilo;

    uint256 internal _siloId;

    constructor(address _daoFeeReceiver)
        ERC721("Silo Finance Fee Receiver", "feeSILO")
        Ownable(msg.sender)
    {
        // start IDs from 1
        _siloId = 1;

        baseURI = "https://v2.app.silo.finance/markets/";

        _setDaoFee({_minFee: 0.05e18, _maxFee: 0.5e18});
        _setDaoFeeReceiver(_daoFeeReceiver);

        _setMaxDeployerFee({_newMaxDeployerFee: 0.15e18}); // 15% max deployer fee
        _setMaxFlashloanFee({_newMaxFlashloanFee: 0.15e18}); // 15% max flashloan fee
        _setMaxLiquidationFee({_newMaxLiquidationFee: 0.30e18}); // 30% max liquidation fee
    }

    function daoFeeRange() external view returns (Range memory) {
        return _daoFeeRange;
    }

    /// @inheritdoc ISiloFactory
    function createSilo( // solhint-disable-line function-max-lines
        ISiloConfig.InitData memory _initData,
        ISiloConfig _siloConfig,
        address _siloImpl,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl
    )
        external
        virtual
    {
        require(
            _siloImpl != address(0) &&
            _shareProtectedCollateralTokenImpl != address(0) &&
            _shareDebtTokenImpl != address(0) &&
            address(_siloConfig) != address(0),
            ZeroAddress()
        );

        ISiloConfig.ConfigData memory configData0;
        ISiloConfig.ConfigData memory configData1;

        (
            configData0, configData1
        ) = Views.copySiloConfig(_initData, _daoFeeRange, maxDeployerFee, maxFlashloanFee, maxLiquidationFee);

        uint256 nextSiloId = _siloId;
        // safe to uncheck, because we will not create 2 ** 256 of silos in a lifetime
        unchecked { _siloId++; }

        configData0.silo = CloneDeterministic.silo0(_siloImpl, nextSiloId);
        configData1.silo = CloneDeterministic.silo1(_siloImpl, nextSiloId);

        _cloneShareTokens(
            configData0,
            configData1,
            _shareProtectedCollateralTokenImpl,
            _shareDebtTokenImpl,
            nextSiloId
        );

        ISilo(configData0.silo).initialize(_siloConfig);
        ISilo(configData1.silo).initialize(_siloConfig);

        _initializeShareTokens(configData0, configData1);

        ISilo(configData0.silo).updateHooks();
        ISilo(configData1.silo).updateHooks();

        idToSiloConfig[nextSiloId] = address(_siloConfig);

        isSilo[configData0.silo] = true;
        isSilo[configData1.silo] = true;

        if (_initData.deployer != address(0)) {
            _mint(_initData.deployer, nextSiloId);
        }

        emit NewSilo(
            _siloImpl,
            configData0.token,
            configData1.token,
            configData0.silo,
            configData1.silo,
            address(_siloConfig)
        );
    }

    /// @inheritdoc ISiloFactory
    function burn(uint256 _siloIdToBurn) external virtual {
        _burn(_siloIdToBurn);
    }

    /// @inheritdoc ISiloFactory
    function setDaoFee(uint128 _minFee, uint128 _maxFee) external virtual onlyOwner {
        _setDaoFee(_minFee, _maxFee);
    }

    /// @inheritdoc ISiloFactory
    function setMaxDeployerFee(uint256 _newMaxDeployerFee) external virtual onlyOwner {
        _setMaxDeployerFee(_newMaxDeployerFee);
    }

    /// @inheritdoc ISiloFactory
    function setMaxFlashloanFee(uint256 _newMaxFlashloanFee) external virtual onlyOwner {
        _setMaxFlashloanFee(_newMaxFlashloanFee);
    }

    /// @inheritdoc ISiloFactory
    function setMaxLiquidationFee(uint256 _newMaxLiquidationFee) external virtual onlyOwner {
        _setMaxLiquidationFee(_newMaxLiquidationFee);
    }

    /// @inheritdoc ISiloFactory
    function setDaoFeeReceiver(address _newDaoFeeReceiver) external virtual onlyOwner {
        _setDaoFeeReceiver(_newDaoFeeReceiver);
    }

    /// @inheritdoc ISiloFactory
    function setBaseURI(string calldata _newBaseURI) external virtual onlyOwner {
        baseURI = _newBaseURI;
        emit BaseURI(_newBaseURI);
    }

    /// @inheritdoc ISiloFactory
    function getNextSiloId() external view virtual returns (uint256) {
        return _siloId;
    }

    /// @inheritdoc ISiloFactory
    function getFeeReceivers(address _silo) external view virtual returns (address dao, address deployer) {
        uint256 siloID = ISilo(_silo).config().SILO_ID();
        return (daoFeeReceiver, _ownerOf(siloID));
    }

    /// @inheritdoc ISiloFactory
    function validateSiloInitData(ISiloConfig.InitData memory _initData) external view virtual returns (bool) {
        return Views.validateSiloInitData(_initData, _daoFeeRange, maxDeployerFee, maxFlashloanFee, maxLiquidationFee);
    }

    /// @inheritdoc ERC721
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireOwned(tokenId);

        return string.concat(
            baseURI,
            Strings.toString(block.chainid),
            "/",
            Strings.toHexString(idToSiloConfig[tokenId])
        );
    }

    function _setDaoFee(uint128 _minFee, uint128 _maxFee) internal virtual {
        require(_maxFee <= MAX_FEE, MaxFeeExceeded());
        require(_minFee <= _maxFee, InvalidFeeRange());
        require(_daoFeeRange.min != _minFee || _daoFeeRange.max != _maxFee, SameRange());

        _daoFeeRange.min = _minFee;
        _daoFeeRange.max = _maxFee;

        emit DaoFeeChanged(_minFee, _maxFee);
    }

    function _setMaxDeployerFee(uint256 _newMaxDeployerFee) internal virtual {
        require(_newMaxDeployerFee <= MAX_FEE, MaxFeeExceeded());

        maxDeployerFee = _newMaxDeployerFee;

        emit MaxDeployerFeeChanged(_newMaxDeployerFee);
    }

    function _setMaxFlashloanFee(uint256 _newMaxFlashloanFee) internal virtual {
        require(_newMaxFlashloanFee <= MAX_FEE, MaxFeeExceeded());

        maxFlashloanFee = _newMaxFlashloanFee;

        emit MaxFlashloanFeeChanged(_newMaxFlashloanFee);
    }

    function _setMaxLiquidationFee(uint256 _newMaxLiquidationFee) internal virtual {
        require(_newMaxLiquidationFee <= MAX_FEE, MaxFeeExceeded());

        maxLiquidationFee = _newMaxLiquidationFee;

        emit MaxLiquidationFeeChanged(_newMaxLiquidationFee);
    }

    function _setDaoFeeReceiver(address _newDaoFeeReceiver) internal virtual {
        require(_newDaoFeeReceiver != address(0), DaoFeeReceiverZeroAddress());

        daoFeeReceiver = _newDaoFeeReceiver;

        emit DaoFeeReceiverChanged(_newDaoFeeReceiver);
    }

    function _cloneShareTokens(
        ISiloConfig.ConfigData memory configData0,
        ISiloConfig.ConfigData memory configData1,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _nextSiloId
    ) internal virtual {
        configData0.collateralShareToken = configData0.silo;
        configData1.collateralShareToken = configData1.silo;

        configData0.protectedShareToken = CloneDeterministic.shareProtectedCollateralToken0(
            _shareProtectedCollateralTokenImpl, _nextSiloId
        );

        configData1.protectedShareToken = CloneDeterministic.shareProtectedCollateralToken1(
            _shareProtectedCollateralTokenImpl, _nextSiloId
        );

        configData0.debtShareToken = CloneDeterministic.shareDebtToken0(_shareDebtTokenImpl, _nextSiloId);
        configData1.debtShareToken = CloneDeterministic.shareDebtToken1(_shareDebtTokenImpl, _nextSiloId);
    }

    function _initializeShareTokens(
        ISiloConfig.ConfigData memory configData0,
        ISiloConfig.ConfigData memory configData1
    ) internal virtual {
        uint24 protectedTokenType = uint24(Hook.PROTECTED_TOKEN);
        uint24 debtTokenType = uint24(Hook.DEBT_TOKEN);

        // initialize configData0
        ISilo silo0 = ISilo(configData0.silo);
        address hookReceiver0 = configData0.hookReceiver;

        IShareTokenInitializable(configData0.protectedShareToken).initialize(silo0, hookReceiver0, protectedTokenType);
        IShareTokenInitializable(configData0.debtShareToken).initialize(silo0, hookReceiver0, debtTokenType);

        // initialize configData1
        ISilo silo1 = ISilo(configData1.silo);
        address hookReceiver1 = configData1.hookReceiver;

        IShareTokenInitializable(configData1.protectedShareToken).initialize(silo1, hookReceiver1, protectedTokenType);
        IShareTokenInitializable(configData1.debtShareToken).initialize(silo1, hookReceiver1, debtTokenType);
    }
}
