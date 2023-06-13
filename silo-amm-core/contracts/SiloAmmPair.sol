// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "uniswap/v2-core/contracts/interfaces/IERC20.sol";

import "./external/libraries/Math.sol";
import "./external/UniswapV2ERC20.sol";

import "./interfaces/ISiloAmmPair.sol";
import "./AmmStateModel.sol";
import "./AmmPriceModel.sol";


contract SiloAmmPair is ISiloAmmPair, UniswapV2ERC20, AmmStateModel, AmmPriceModel {
    uint public constant MINIMUM_LIQUIDITY = 10**3;

    /// @dev _TOKEN_0 < _TOKEN_1
    address internal immutable _TOKEN_0; // solhint-disable-line var-name-mixedcase
    address internal immutable _TOKEN_1; // solhint-disable-line var-name-mixedcase

    /// @dev gives token0 price in token1
    ISiloOracle public immutable ORACLE_0; // solhint-disable-line var-name-mixedcase
    ISiloOracle public immutable ORACLE_1; // solhint-disable-line var-name-mixedcase

    /// @dev address of Silo with witch we cresting 1:1 bond for liquidity management
    address internal immutable _SILO; // solhint-disable-line var-name-mixedcase

    address internal immutable _FEE_TO; // solhint-disable-line var-name-mixedcase

    address internal immutable _ROUTER; // solhint-disable-line var-name-mixedcase

    /// @dev flag, that tell us, if we have two oracle set up or one
    OracleSetup immutable private _ORACLE_SETUP; // solhint-disable-line var-name-mixedcase

    uint112 internal _token0Reserve;           // uses single storage slot, accessible via getReserves
    uint112 internal _token1Reserve;           // uses single storage slot, accessible via getReserves

    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    bool private _locked; // todo move to save gas

    modifier lock() {
        if (_locked) revert LOCKED();
        _locked = false;
        _;
        _locked = true;
    }

    modifier onlySilo() {
        if (msg.sender != _SILO) revert ONLY_SILO();
        _;
    }

    /// @dev tokens must be sorted
    constructor(
        address _router,
        address _silo,
        address _token0,
        address _token1,
        address _feeTo,
        ISiloOracle _oracle0,
        ISiloOracle _oracle1,
        AmmPriceConfig memory _config
    )
        AmmPriceModel(_config)
    {
        // tokens verification is done by silo
        _TOKEN_0 = _token0;
        _TOKEN_1 = _token1;

        if (_router == address(0)) revert ZERO_ADDRESS();
        _ROUTER = _router;

        // zero check is enough, we don"t need to check, if this is real silo, ...or do we?? :]
        if (_silo == address(0)) revert ZERO_ADDRESS();

        _SILO = _silo;

        // can be zero
        _FEE_TO = _feeTo;

        ORACLE_0 = _oracle0;
        ORACLE_1 = _oracle1;

        _ORACLE_SETUP = _oracleSetup(address(_oracle0), address(_oracle1));
    }

    // TODO can we swap instead of add liquidity?
    /// @notice endpoint for liquidation, here borrower collateral is added as liquidity
    /// THIS METHOD BLINDLY TRUST SILO TO TRANSFER TOKENS
    /// @dev User adds `dC` units of collateral to the pool and receives shares.
    /// Liquidation-time value of the collateral at the current spot price P(t) is added to the user’s count.
    /// The variable R is updated so that it keeps track of the sum of Ri
    /// @param _collateral address of collateral token that is been deposited into pool
    /// @param _user depositor, owner of position
    /// @param _collateralAmount amount of collateral
    /// @param _collateralValue value that is: collateralPrice * collateralAmount / DECIMALS,
    /// where collateralPrice is current price P(T) of collateral denominate in ???? TODO
    function addLiquidity(address _collateral, address _user, uint256 _collateralAmount, uint256 _collateralValue)
        external
        onlySilo
        returns (uint256 shares)
    {
        shares = _addLiquidity(_collateral, _user, _collateralAmount, _collateralValue);
        _init(_collateral);
        _onAddingLiquidity(_collateral);
    }

    /// @param _collateral token address for which liquidity was added
    /// @param _user owner of position
    /// @param _w fraction of user position that needs to be withdrawn, 0 < _w <= 100%
    /// @return debtAmount that is withdrawn
    function removeLiquidity(address _collateral, address _user, uint256 _w)
        external
        onlySilo
        returns (uint256 debtAmount)
    {
        if (_w > ONE) revert PERCENT_OVERFLOW();

        debtAmount = _w == ONE
            ? _withdrawAllLiquidity(_collateral, _user)
            : _withdrawLiquidity(_collateral, _user, _w);

        address debtToken = _collateral == _TOKEN_0 ? _TOKEN_1 : _TOKEN_0;

        _onWithdraw(_collateral);

        _safeTransfer(debtToken, msg.sender, debtAmount);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint _amount0Out, uint _amount1Out, address _to, bytes calldata _data) external lock {
        if (_amount0Out == 0 && _amount1Out == 0) revert INSUFFICIENT_OUTPUT_AMOUNT();
        if (_amount0Out != 0 && _amount1Out != 0) revert INVALID_OUT();
        if (_to == _TOKEN_0 || _to == _TOKEN_1) revert INVALID_TO();

        bool token0In = _amount0Out == 0;
        // collateral is always the one that will be OUT of the pool
        address collateral = token0In ? _TOKEN_1 : _TOKEN_0;
        address debtToken = token0In ? _TOKEN_0 : _TOKEN_1;

        _onSwapPriceChange(collateral);
        uint256 _collateralOut = token0In ? _amount1Out : _amount1Out;
        uint256 _collateralTwapPrice = getOraclePrice(collateral, _collateralOut);
        uint256 _debtIn = collateralPrice(collateral, _collateralOut, _collateralTwapPrice);
        _onSwapStateChange(collateral, _collateralOut, _debtIn);

        // TODO let"s make unlimited allowance, it might save gas
        _safeTransferFrom(collateral, _SILO, _to, _collateralOut);
        _safeTransferFrom(debtToken, _to, address(this), _debtIn);

        if (_data.length != 0) {
            // TODO do we need it??
            IUniswapV2Callee(_to).uniswapV2Call(msg.sender, _amount0Out, _amount1Out, _data);
        }

        // (uint256 amount0In, uint256 amount1In) = token0In ? (_debtIn, uint256(0)) : (uint256(0), _debtIn);
        // TODO temporary disable emit because stack too deep and I want to test math
        // emit Swap(msg.sender, amount0In, amount1In, _amount0Out, _amount1Out, _to);
    }

    /// @dev this is only for backward compatibility with uniswapV2
    /// @return router address in returned, because in our case, router takes over factory interface
    function factory() external view returns (address) {
        return _ROUTER;
    }

    function silo() external view returns (address) {
        return _SILO;
    }

    function token0() external view returns (address) {
        return _TOKEN_0;
    }

    function token1() external view returns (address) {
        return _TOKEN_1;
    }

    function feeTo() external view returns (address) {
        return _FEE_TO;
    }

    function initialize(address, address) external pure {
        revert NOT_SUPPORTED();
    }

    function mint(address) external pure returns (uint) {
        revert NOT_SUPPORTED();
    }

    function burn(address) external pure returns (uint, uint){
        revert NOT_SUPPORTED();
    }

    function price0CumulativeLast() external pure returns (uint) {
        revert NOT_SUPPORTED();
    }

    function price1CumulativeLast() external pure returns (uint) {
        revert NOT_SUPPORTED();
    }

    // force balances to match reserves
    function skim(address) external pure {
        revert NOT_SUPPORTED();
    }

    // force reserves to match balances
    function sync() external pure {
        revert NOT_SUPPORTED();
    }

    /// @return reserve0
    /// @return reserve1
    /// @return blockTimestampLast is always 0, we do not support Oracle functionality
    function getReserves() public view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        // TODO if univ2 can handle reserves in uint112 then maybe so do we? QA and verify
        reserve0 = uint112(_totalStates[_TOKEN_0].collateralAmount);
        reserve1 = uint112(_totalStates[_TOKEN_1].collateralAmount);
        blockTimestampLast = 0;
    }

    // TODO once Edd has code we can complete that logic
    function getOraclePrice(address _collateral, uint256 _collateralAmount) public view returns (uint256 debtPrice) {
        if (_ORACLE_SETUP == OracleSetup.BOTH) {
            //
        } else if (_ORACLE_SETUP == OracleSetup.NONE) {
            // if (ORACLE_0 == 0 && ORACLE_1 == 0) return _collateralAmount; do we support this case?
        } else if (_ORACLE_SETUP == OracleSetup.FOR_TOKEN0) {
            if (_collateral == _TOKEN_0) {
                // we have only one oracle and it is for our `_collateral` so this case is straight forward
                debtPrice = ORACLE_0.quoteView(_collateralAmount, _TOKEN_0); // return price in _TOKEN_1
            } else {
                // we have only one oracle, but is not set for `_collateral` token, but for other one
                // so lal we need to change base? => so we can simply remove this last if?
                // and it does not matter for which token is is set as always using this oracle for both tokens?
                debtPrice = ORACLE_0.quoteView(_collateralAmount, _TOKEN_1);
            }
        }
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) internal returns (bool feeOn) {
        feeOn = _FEE_TO != address(0);
        uint _kLast = kLast; // gas savings

        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
                uint rootKLast = Math.sqrt(_kLast);

                if (rootK > rootKLast) {
                    uint numerator = totalSupply * (rootK - rootKLast);
                    uint denominator = rootK * 5 + rootKLast;
                    uint liquidity;
                    unchecked { liquidity = numerator / denominator; }

                    if (liquidity != 0) _mint(_FEE_TO, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Errors with ST if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ST");
    }

    /// @notice Transfers tokens from the targeted address to the given destination
    /// @notice Errors with "STF" if transfer fails
    /// @param token The contract address of the token to be transferred
    /// @param from The originating address from which the tokens will be transferred
    /// @param to The destination address of the transfer
    /// @param value The amount to be transferred
    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (
            bool success,
            bytes memory data
        // solhint-disable-next-line avoid-low-level-calls
        ) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));

        require(success && (data.length == 0 || abi.decode(data, (bool))), "STF");
    }

    function _oracleSetup(address _oracle0, address _oracle1) internal pure returns (OracleSetup) {
        if (_oracle0 == address(0) && _oracle1 == address(0)) return OracleSetup.NONE;
        if (_oracle0 != address(0) && _oracle1 != address(0)) return OracleSetup.BOTH;
        if (_oracle0 == address(0)) return OracleSetup.FOR_TOKEN1;

        return OracleSetup.FOR_TOKEN0;
    }
}
