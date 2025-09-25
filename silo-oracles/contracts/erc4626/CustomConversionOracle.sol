// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

contract CustomConversionOracle is ISiloOracle {
    address public immutable VAULT;
    bytes4 public immutable CONVERSION_FUNCTION_SELECTOR;

    address internal immutable _QUOTE_TOKEN;

    string public conversionFunction;

    error AssetNotSupported();
    error VaultZeroAddress();
    error QuoteTokenZeroAddress();
    error ZeroPrice();
    error ConversionFunctionEmpty();
    error ConversionFunctionFailed();

    constructor(address _vault, string memory _conversionFunction, address _quoteToken) {
        require(_vault != address(0), VaultZeroAddress());
        require(_quoteToken != address(0), QuoteTokenZeroAddress());
        require(bytes(_conversionFunction).length >= 6, ConversionFunctionEmpty()); // min expected is "a(int)"

        VAULT = _vault;
        conversionFunction = _conversionFunction;
        CONVERSION_FUNCTION_SELECTOR = bytes4(keccak256(bytes(_conversionFunction)));
        _QUOTE_TOKEN = _quoteToken;
    }

    /// @inheritdoc ISiloOracle
    function beforeQuote(address _baseToken) external view {
        // only for an ISiloOracle interface implementation
    }

    /// @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external view returns (uint256 quoteAmount) {
        if (_baseToken != address(VAULT)) revert AssetNotSupported();

        (bool success, bytes memory data) = VAULT.staticcall(abi.encodeWithSelector(CONVERSION_FUNCTION_SELECTOR, _baseAmount));
        if (!success) revert ConversionFunctionFailed();

        quoteAmount = abi.decode(data, (uint256));

        if (quoteAmount == 0) revert ZeroPrice();
    }

    /// @inheritdoc ISiloOracle
    function quoteToken() external view virtual returns (address) {
        return _QUOTE_TOKEN;
    }
}
