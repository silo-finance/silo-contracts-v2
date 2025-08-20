// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Initializable} from  "openzeppelin5-upgradeable/proxy/utils/Initializable.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IFixedPricePTAMMOracleConfig} from "../../interfaces/IFixedPricePTAMMOracleConfig.sol";



contract FixedPricePTAMMOracle is IFixedPricePTAMMOracle, ISiloOracle, Initializable {
    IFixedPricePTAMMOracleConfig public oracleConfig;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice validation of config is checked in factory, therefore you should not deploy and initialize directly
    /// use factory always.
    function initialize(IFixedPricePTAMMOracleConfig _configAddress) external virtual initializer {
        require(address(_configAddress) != address(0), EmptyConfigAddress());

        oracleConfig = _configAddress;
        emit FixedPricePTAMMOracleInitialized(_configAddress);
    }

    /// @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external view virtual returns (uint256 quoteAmount) {
        IFixedPricePTAMMOracleConfig.Config memory cfg = oracleConfig.getConfig();
        require(cfg.quoteToken != address(0), NotInitialized());

        require(_baseToken == cfg.baseToken, AssetNotSupported());
        require(_baseAmount <= type(uint128).max, BaseAmountOverflow());

        quoteAmount = cfg.amm.previewSwapExactPtForToken(_baseToken, _baseAmount, cfg.quoteToken);

        require(quoteAmount != 0, ZeroQuote());
    }

    /// @inheritdoc ISiloOracle
    function quoteToken() external view virtual returns (address) {
        return oracleConfig.getConfig().quoteToken;
    }
}
