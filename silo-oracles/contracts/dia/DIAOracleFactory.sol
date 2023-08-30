// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ClonesUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import {OracleFactory} from "../_common/OracleFactory.sol";
import {DIAOracle, IDIAOracle} from "../dia/DIAOracle.sol";
import {DIAOracleConfig} from "../dia/DIAOracleConfig.sol";
import {OracleNormalization} from "../lib/OracleNormalization.sol";

contract DIAOracleFactory is OracleFactory {
    /// @dev price provider needs to return prices in ETH, but assets prices provided by DIA are in USD
    /// Under ETH_USD_KEY we will find ETH price in USD so we can convert price in USD into price in ETH
    string public constant ETH_USD_KEY = "ETH/USD";

    /// @dev decimals in DIA oracle
    uint256 public constant DIA_DECIMALS = 8;

    /// @dev address that will be used to determine, if token address is ETH
    /// DIA is not operating based on addresses, so this can be any address eg WETH or 0xEeEe...
    /// if address(0) then this feature will be disabled and USD will be quote token
    address public immutable ETH_ADDRESS; // solhint-disable-line var-name-mixedcase

    error InvalidHeartbeat();

    constructor(address _ethAddress) OracleFactory(address(new DIAOracle())) {
        // zero means disabled
        ETH_ADDRESS = _ethAddress;
    }

    function create(IDIAOracle.DIAConfig memory _config)
        external
        virtual
        returns (DIAOracle oracle)
    {
        bytes32 id = hashConfig(_config);
        DIAOracleConfig oracleConfig = DIAOracleConfig(getConfigAddress[id]);

        if (address(oracleConfig) != address(0)) {
            // config already exists, so oracle exists as well
            return DIAOracle(getOracleAddress[address(oracleConfig)]);
        }

        bool quoteIsEth = address(_config.quoteToken) == ETH_ADDRESS;

        verifyHeartbeat(_config.heartbeat);

        if (!quoteIsEth) {
            verifyStablecoin(_config.quoteToken.symbol());
        }

        string memory diaKey = createKey(_config.baseToken);

        (uint256 divider, uint256 multiplier) = OracleNormalization.normalizationNumbers(
            _config.baseToken, _config.quoteToken, DIA_DECIMALS, quoteIsEth ? DIA_DECIMALS : 0
        );

        oracleConfig = new DIAOracleConfig(_config, quoteIsEth, divider, multiplier, diaKey);

        oracle = DIAOracle(ClonesUpgradeable.clone(ORACLE_IMPLEMENTATION));

        _saveOracle(address(oracle), address(oracleConfig), id);

        oracle.initialize(oracleConfig);
    }

    function hashConfig(IDIAOracle.DIAConfig memory _config)
        public
        virtual
        view
        returns (bytes32 configId)
    {
        configId = keccak256(abi.encode(_config));
    }

    /// @dev creates KEY based on symbol of base token
    /// @param _baseToken address of base token
    /// @return under this key asset price should be available in DIA oracle
    function createKey(IERC20Metadata _baseToken) public view virtual returns (string memory) {
        string memory baseSymbol = _baseToken.symbol();
        return string(abi.encodePacked(baseSymbol, "/USD"));
    }

    function verifyHeartbeat(uint256 _heartbeat) public view virtual {
        // heartbeat restrictions are arbitrary
        if (_heartbeat < 60 seconds || _heartbeat > 2 days) revert InvalidHeartbeat();
    }
}
