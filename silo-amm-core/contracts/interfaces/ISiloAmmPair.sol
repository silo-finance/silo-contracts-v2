// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "../external/interfaces/IUniswapV2Pair.sol";

interface ISiloAmmPair is IUniswapV2Pair {
    enum OracleSetup { NONE, BOTH, FOR_TOKEN0, FOR_TOKEN1 }

    error ONLY_SILO();
    error NOT_SUPPORTED();
    error ZERO_SHARES();

    error ZERO_ADDRESS();
    error LOCKED();
    error TRANSFER_FAILED();
    error OVERFLOW();
    error PERCENT_OVERFLOW();
    error INSUFFICIENT_LIQUIDITY_MINTED();
    error INSUFFICIENT_LIQUIDITY_BURNED();
    error INSUFFICIENT_OUTPUT_AMOUNT();
    error INSUFFICIENT_LIQUIDITY();
    error INVALID_TO();
    error INVALID_OUT();
    error INSUFFICIENT_INPUT_AMOUNT();
    error K();

    /// @notice endpoint for liquidation, here borrower collateral is added as liquidity
    /// THIS METHOD BLINDLY TRUST SILO BECAUSE OF 1:1 BOND
    /// @dev User adds `dC` units of collateral to the pool and receives shares.
    /// Liquidation-time value of the collateral at the current spot price P(t) is added to the user’s count.
    /// The variable R is updated so that it keeps track of the sum of Ri
    /// @param _collateral address of collateral token that is been deposited into pool
    /// @param _user depositor, owner of position
    /// @param _cleanUp flag that indicates, if cleanup needs to be done before adding liquidity
    /// assumption here is, that Silo will have that info ready and can pass it, so we do not need to run additional
    /// checks and also Silo don't have to do additional external calls
    /// @param _collateralAmount amount of collateral
    /// @param _collateralValue value that is: collateralPrice * collateralAmount / DECIMALS,
    /// where collateralPrice is current price P(T) of collateral
    function addLiquidity(
        address _collateral,
        address _user,
        bool _cleanUp,
        uint256 _collateralAmount,
        uint256 _collateralValue
    )
        external
        returns (uint256 shares);

    /// @param _collateral token address for which liquidity was added
    /// @param _user owner of position
    /// @param _w fraction of user position that needs to be withdrawn, 0 < _w <= 100%
    /// @return debtAmount that is withdrawn
    function removeLiquidity(address _collateral, address _user, uint256 _w)
        external
        returns (uint256 debtAmount);

    function feeTo() external view returns (address);
    function silo() external view returns (address);
}
