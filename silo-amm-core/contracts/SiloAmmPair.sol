// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";

import "./external/UniswapV2ERC20.sol";

import "./interfaces/NotSupportedInPair.sol";
import "./AmmStateModel.sol";
import "./AmmPriceModel.sol";
import "./utils/SafeTransfers.sol";
import "./lib/PairMath.sol";


contract SiloAmmPair is NotSupportedInPair, SafeTransfers, UniswapV2ERC20, AmmStateModel, AmmPriceModel {
    // TODO when we check exponential operations on shares we will decide if we need minimum liquidity
    uint public constant MINIMUM_LIQUIDITY = 10**3;

    /// @dev _TOKEN_0 < _TOKEN_1
    address internal immutable _TOKEN_0; // solhint-disable-line var-name-mixedcase
    address internal immutable _TOKEN_1; // solhint-disable-line var-name-mixedcase

    /// @dev in case of two oracle setup, we using bridge token to get quote
    address public immutable BRIDGE_TOKEN; // solhint-disable-line var-name-mixedcase

    /// @dev gives token0 price in token1
    ISiloOracle public immutable ORACLE_0; // solhint-disable-line var-name-mixedcase
    ISiloOracle public immutable ORACLE_1; // solhint-disable-line var-name-mixedcase

    /// @dev when only one oracle is set for either token, its address is stored here for easier access to read price
    /// both ways token0->token1 and token1->token0
    ISiloOracle public immutable ORACLE_SINGLE; // solhint-disable-line var-name-mixedcase

    /// @dev address of Silo with witch we cresting 1:1 bond for liquidity management
    address internal immutable _SILO; // solhint-disable-line var-name-mixedcase

    address internal immutable _FEE_TO; // solhint-disable-line var-name-mixedcase

    address internal immutable _ROUTER; // solhint-disable-line var-name-mixedcase

    /// @dev flag, that tell us, if we have two oracle set up or one
    OracleSetup public immutable ORACLE_SETUP; // solhint-disable-line var-name-mixedcase

    uint112 internal _token0Reserve;           // uses single storage slot, accessible via getReserves
    uint112 internal _token1Reserve;           // uses single storage slot, accessible via getReserves

    uint256 public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint256 private _unlocked = 1;

    modifier lock() {
        if (_unlocked == 0) revert LOCKED();
        _unlocked = 0;
        _;
        _unlocked = 1;
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
        ISiloOracle _oracle0,
        ISiloOracle _oracle1,
        address _bridgeQuoteToken,
        AmmPriceConfig memory _config
    )
        AmmPriceModel(_config)
    {
        // tokens verification is done by silo
        _TOKEN_0 = _token0;
        _TOKEN_1 = _token1;

        if (_router == address(0)) revert ZERO_ADDRESS();
        // zero check is enough, we don't need to check, if this is real silo
        if (_silo == address(0)) revert ZERO_ADDRESS();

        _ROUTER = _router;
        _SILO = _silo;

        // TODO
        _FEE_TO = address(0);

        (
            ORACLE_SETUP,
            ORACLE_0,
            ORACLE_1,
            ORACLE_SINGLE,
            BRIDGE_TOKEN
        ) = _oracleSetup(address(_oracle0), address(_oracle1), _bridgeQuoteToken);
    }

    /// @inheritdoc ISiloAmmPair
    function addLiquidity(
        address _collateralToken,
        address _user,
        bool _cleanUp,
        uint256 _collateralAmount,
        uint256 _collateralValue
    )
        external
        virtual
        onlySilo
        returns (uint256 shares)
    {
        if (_cleanUp) {
            removeLiquidity(_collateralToken, _user, PRECISION);
        }

        uint256 availableCollateralBefore;
        uint256 availableCollateralAfter;

        (
            availableCollateralBefore,
            availableCollateralAfter,
            shares
        ) = _onAddLiquidityStateChange(_collateralToken, _user, _collateralAmount, _collateralValue);

        if (shares == 0) revert ZERO_SHARES();

        _priceInit(_collateralToken);
        _onAddingLiquidityPriceChange(_collateralToken, availableCollateralBefore, availableCollateralAfter);
    }

    /// @inheritdoc IUniswapV2Pair
    function swap(uint256 _amount0Out, uint256 _amount1Out, address _to, bytes calldata _data)
        external
        virtual
        lock
        returns (uint256 amountIn)
    {
        if (_amount0Out == 0 && _amount1Out == 0) revert INSUFFICIENT_OUTPUT_AMOUNT();
        if (_amount0Out != 0 && _amount1Out != 0) revert INVALID_OUT();
        if (_to == _TOKEN_0 || _to == _TOKEN_1) revert INVALID_TO();

        bool token0In = _amount0Out == 0;

        // collateral is always the one, that will be OUT of the pool
        (address collateralToken, address debtToken, uint256 collateralAmountOut) = token0In
            ? (_TOKEN_1, _TOKEN_0, _amount1Out)
            : (_TOKEN_0, _TOKEN_1, _amount0Out);

        uint256 k = _onSwapCalculateK(collateralToken, block.timestamp);
        _onSwapPriceChange(collateralToken, uint64(k));

        uint256 debtQuote = getQuoteFromOracle(collateralAmountOut, collateralToken);
        amountIn = PairMath.getDebtIn(debtQuote, k);
        
        if (amountIn == 0) revert INSUFFICIENT_INPUT_AMOUNT();

        _finishSwap(collateralToken, debtToken, token0In, amountIn, collateralAmountOut, _to, _data);
    }

    /// @inheritdoc ISiloAmmPair
    function exactInSwap(address _tokenIn, uint256 _amountIn, address _to, bytes calldata _data)
        external
        virtual
        lock
        returns (uint256 amountOut)
    {
        if (_amountIn == 0) revert INSUFFICIENT_INPUT_AMOUNT();
        if (_to == _TOKEN_0 || _to == _TOKEN_1) revert INVALID_TO();

        bool token0In = _tokenIn == _TOKEN_0;

        // collateral is always the one, that will be OUT of the pool
        address collateral = token0In ? _TOKEN_1 : _TOKEN_0;

        uint256 k = _onSwapCalculateK(collateral, block.timestamp);
        _onSwapPriceChange(collateral, uint64(k));

        // REVERSE calculation of what we have in `swap`
        uint256 virtualDebtIn = PairMath.getDebtInReverse(_amountIn, k);
        amountOut = getQuoteFromOracle(virtualDebtIn, _tokenIn);
        if (amountOut == 0) revert INSUFFICIENT_OUTPUT_AMOUNT();

        _finishSwap(collateral, _tokenIn, token0In, _amountIn, amountOut, _to, _data);
    }

    /// @inheritdoc ISiloAmmPair
    function getAmountIn(address _tokenOut, uint256 _amountOut, uint256 _timestamp)
        external
        virtual
        view
        returns (uint256 amountIn)
    {
        if (_timestamp == 0) {
            _timestamp = block.timestamp;
        } else if (_timestamp < block.timestamp) revert TIME_UNDERFLOW();

        if (_amountOut == 0) {
            return 0;
        }

        uint256 k = _onSwapCalculateK(_tokenOut, _timestamp);
        uint256 debtQuote = getQuoteFromOracle(_amountOut, _tokenOut);
        amountIn = PairMath.getDebtIn(debtQuote, k);
    }

    /// @inheritdoc ISiloAmmPair
    function getAmountOut(address _tokenIn, uint256 _amountIn, uint256 _timestamp)
        external
        virtual
        view
        returns (uint256 amountOut)
    {
        if (_timestamp == 0) {
            _timestamp = block.timestamp;
        } else if (_timestamp < block.timestamp) revert TIME_UNDERFLOW();

        if (_amountIn == 0) {
            return 0;
        }

        address collateral = _tokenIn == _TOKEN_0 ? _TOKEN_1 : _TOKEN_0;
        uint256 k = _onSwapCalculateK(collateral, _timestamp);
        uint256 virtualDebtIn = PairMath.getDebtInReverse(_amountIn, k);
        amountOut = getQuoteFromOracle(virtualDebtIn, _tokenIn);
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

    /// @inheritdoc ISiloAmmPair
    function removeLiquidity(address _collateralToken, address _user, uint256 _w)
        public
        virtual
        onlySilo
        returns (uint256 debtAmount)
    {
        if (_w > PRECISION) revert PERCENT_OVERFLOW();

        debtAmount = _w == PRECISION
            ? _withdrawAllLiquidity(_collateralToken, _user)
            : _withdrawLiquidity(_collateralToken, _user, _w);

        _onWithdrawPriceChange(_collateralToken);
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

    /// @return quoteAmount amount of quote token that represents value of `_baseToken` and `_baseAmount`
    function getQuoteFromOracle(uint256 _baseAmount, address _baseToken)
        public
        view
        virtual
        returns (uint256 quoteAmount)
    {
        if (ORACLE_SETUP == OracleSetup.ONE) {
            quoteAmount = ORACLE_0.quoteView(_baseAmount, _baseToken);
        } else if (ORACLE_SETUP == OracleSetup.BOTH) {
            (ISiloOracle one, ISiloOracle two) = _baseToken == _TOKEN_0 ? (ORACLE_0, ORACLE_1) : (ORACLE_1, ORACLE_0);
            quoteAmount = one.quoteView(_baseAmount, _baseToken);
            quoteAmount = two.quoteView(quoteAmount, BRIDGE_TOKEN);
        } else { // if (ORACLE_SETUP == OracleSetup.NONE)
            quoteAmount = _baseAmount;
        }
    }

    function _finishSwap(
        address _collateralToken,
        address _debt,
        bool _token0In,
        uint256 _amountIn,
        uint256 _amountOut,
        address _to,
        bytes calldata _data
    )
        internal
        virtual
    {
        _onSwapStateChange(_collateralToken, _amountOut, _amountIn);

        if (_token0In) {
            emit Swap(msg.sender, _amountIn, uint256(0), uint256(0), _amountOut, _to);
        } else {
            emit Swap(msg.sender, uint256(0), _amountIn, _amountOut, uint256(0), _to);
        }

        // we doing transfer directly to SILO, but state will be updated on withdraw
        _safeTransferFrom(_debt, msg.sender, _SILO, _amountIn);
        _safeTransferFrom(_collateralToken, _SILO, _to, _amountOut);

        if (_data.length != 0) {
            // keep it for backwards compatibility and allow flash swap
            (uint256 _amount0Out, uint256 _amount1Out) = _token0In
                ? (uint256(0), _amountOut)
                : (_amountOut, uint256(0));

            IUniswapV2Callee(_to).uniswapV2Call(msg.sender, _amount0Out, _amount1Out, _data);
        }
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 /* _reserve0 */, uint112 /* _reserve1 */) internal returns (bool feeOn) {
        feeOn = _FEE_TO != address(0);
        uint _kLast = kLast; // gas savings

        if (feeOn) {
            if (_kLast != 0) {
                uint rootK; // TODO = Math.sqrt(uint256(_reserve0) * _reserve1);
                uint rootKLast; // = Math.sqrt(_kLast);

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

    function _oracleSetup(address _oracle0, address _oracle1, address _bridgeQuoteToken)
        internal
        pure
        returns (
            OracleSetup setup,
            ISiloOracle oracle0,
            ISiloOracle oracle1,
            ISiloOracle oracleSingle,
            address bridgeQuoteToken
        )
    {
        if (_oracle0 == address(0) && _oracle1 == address(0)) {
            setup = OracleSetup.NONE;
        } else if (_oracle0 != address(0) && _oracle1 != address(0)) {
            oracle0 = ISiloOracle(_oracle0);
            oracle1 = ISiloOracle(_oracle1);
            bridgeQuoteToken = _bridgeQuoteToken;
            setup = OracleSetup.BOTH;
        } else {
            setup = OracleSetup.ONE;
            oracleSingle = ISiloOracle(_oracle0 == address(0) ? _oracle1 : _oracle0);
        }
    }
}
