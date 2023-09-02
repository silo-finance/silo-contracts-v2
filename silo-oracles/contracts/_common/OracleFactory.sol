// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6 <0.9.0;


abstract contract OracleFactory {
    /// @dev implementation that will be cloned
    address public immutable ORACLE_IMPLEMENTATION; // solhint-disable-line var-name-mixedcase

    /// @dev hash(config) => oracle contract
    /// oracle ID is determine by initial configuration, the logic is the same, so config is the only difference
    /// that's why we can use it as ID, at the same time we can detect duplicated and save gas by reusing same config
    /// multiple times
    mapping(bytes32 => address) public getConfigAddress;

    /// @dev config address => oracle address
    mapping(address => address) public getOracleAddress;

    /// @dev config ID and config address should be easily accessible directly from oracle contract
    event NewOracle(address indexed oracle);

    constructor(address _oracleImplementation) {
        if (_oracleImplementation == address(0)) revert("ZeroAddress");

        ORACLE_IMPLEMENTATION = _oracleImplementation;
    }

    /// @dev there is no way to verify if quote token is actual stablecoin. DIA is providing prices in USD.
    /// At least we can do is check token symbol. In case we need different stablecoin we can always
    /// override this method.
    /// quote decimals does not matter because DIA has 8 decimals for all prices
    function verifyStablecoin(string memory _symbol) public view virtual {
        bytes32 symbolHash = keccak256(abi.encodePacked(_symbol));

        if (symbolHash == keccak256(abi.encodePacked("USDC"))) return;
        if (symbolHash == keccak256(abi.encodePacked("USDT"))) return;
        if (symbolHash == keccak256(abi.encodePacked("TUSD"))) return;

        revert ("NotSupportedStablecoin");
    }

    /// @dev execute this method from target factory, to save ID and update mappings
    /// @param _newOracle new oracle address
    /// @param _newConfig oracle config address
    /// @param _configId oracle config ID, hash(config)
    function _saveOracle(address _newOracle, address _newConfig, bytes32 _configId) internal virtual {
        if (getConfigAddress[_configId] != address(0)) revert("ConfigAlreadyExist");

        getConfigAddress[_configId] = _newConfig;
        // config and oracle is 1:1 so no need to check if oracle exists
        getOracleAddress[_newConfig] = _newOracle;

        emit NewOracle(_newOracle);
    }
}
