// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

import "silo-amm-core/contracts/interfaces/ISiloAmmPairFactory.sol";
import "silo-amm-core/contracts/external/interfaces/ISiloOracle.sol";
import "silo-amm-core/contracts/utils/SafeTransfers.sol";

import "./libraries/UniswapV2Library.sol";
import "./libraries/Ping.sol";
import "./interfaces/NotSupportedRouter.sol";
import "./utils/SafeTransferETH.sol";


/// @dev based on UniswapV2Router02
contract SiloAmmRouter is NotSupportedRouter, SafeTransferETH, SafeTransfers {
    ISiloAmmPairFactory public immutable PAIR_FACTORY; // solhint-disable-line var-name-mixedcase
    address public immutable WETH; // solhint-disable-line var-name-mixedcase

    /// @dev token0 => token1 => ID => pair
    mapping(address => mapping(address => mapping(uint256 => IUniswapV2Pair))) internal _pairs;

    /// @dev token0 => token1 => number of pairs
    mapping(address => mapping(address => uint256)) internal _sameTypePairsCount;

    /// @dev index of all available pairs
    address[] public allPairs;

    modifier ensure(uint deadline) {
        if (deadline < block.timestamp) revert UNISWAPV2_ROUTER_EXPIRED();
        _;
    }

    constructor(ISiloAmmPairFactory _pairFactory, address _weth) {
        if (!Ping.pong(_pairFactory.siloAmmPairFactoryPing)) revert SILO_AMM_PAIR_FACTORY_PING();
        if (_weth == address(0)) revert WETH_ZERO();

        PAIR_FACTORY = _pairFactory;
        WETH = _weth;
    }

    /*
        TODO
        basic deployment of pair is 2,6M gas atm, let's say it will be 3M
        simple proxy requires 2 storage reads (implementation + config) and external call => 10-13,5K of gas => ~11,7K
        so it needs 256 tx to balance out,
        if we talking about add-swap-remove flow (3 tx), then it will be only 85 "flows",
        then should we use proxy in that case??

        also, if we use proxy+config, we can use create2 and save on getPair storage read,
        will that be cheaper in general?
        I will check this in separate PR, once we have everything ready
    */
    /// @inheritdoc ISiloAmmRouter
    function createPair(
        address _silo,
        address _token0,
        address _token1,
        ISiloOracle _oracle0,
        ISiloOracle _oracle1,
        address _bridge,
        IAmmPriceModel.AmmPriceConfig memory _config
    )
        external
        virtual
        returns (ISiloAmmPair pair)
    {
        uint256 id = allPairs.length;

        // below will never happen, as request is coming from silo factory
        // if (_tokenA == _tokenB) revert IDENTICAL_ADDRESSES();
        // if (token0 == address(0)) revert ZERO_ADDRESS();

        // TODO there is one issue with it - we can not deploy routerV2, because the whole state will be
        // inside old router
        pair = PAIR_FACTORY.createPair(_silo, _token0, _token1, _oracle0, _oracle1, _bridge, _config);

        _pairs[_token0][_token1][id] = IUniswapV2Pair(address(pair));
        _pairs[_token1][_token0][id] = IUniswapV2Pair(address(pair));
        // we will not overflow in lifetime
        unchecked { _sameTypePairsCount[_token0][_token1]++; }

        allPairs.push(address(IUniswapV2Pair(address(pair))));

        // UniswapV2 compatible event
        emit PairCreated(_token0, _token1, address(pair), id);

        IERC20(_token0).approve(address(pair), type(uint256).max);
        IERC20(_token1).approve(address(pair), type(uint256).max);
    }

    /// @inheritdoc IUniswapV2Router01
    function swapExactTokensForTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external virtual override ensure(_deadline) returns (uint256[] memory amounts) {
        _safeTransferFrom(_path[0], msg.sender, address(this), _amountIn);
        amounts = _swapIn(_amountIn, _path, _to);

        unchecked {
            if (amounts[amounts.length - 1] < _amountOutMin) revert UNISWAPV2_ROUTER_INSUFFICIENT_OUTPUT_AMOUNT();
        }
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = UniswapV2Library.getAmountsIn(amountOut, path);
        if (amounts[0] > amountInMax) revert UNISWAPV2_ROUTER_EXCESSIVE_INPUT_AMOUNT();

        _safeTransferFrom(path[0], msg.sender, path[1], amounts[0]);
        _swap(amounts, path, to);
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        _safeTransferFrom(path[0], msg.sender, path[1], amountIn);
        uint lastId;
        unchecked { lastId = path.length - 1; }
        uint balanceBefore = IERC20(path[lastId]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);

        if (IERC20(path[lastId]).balanceOf(to) - balanceBefore < amountOutMin)
            revert UNISWAPV2_ROUTER_INSUFFICIENT_OUTPUT_AMOUNT();
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        external
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        external
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(amountOut, path);
    }

    function getReserves(
        IUniswapV2Pair _pair,
        address _tokenA,
        address _tokenB
    ) external view returns (uint reserveA, uint reserveB) {
        return UniswapV2Library.getReserves(_pair, _tokenA, _tokenB);
    }

    function pairFor(
        address _tokenA,
        address _tokenB,
        uint256 _id
    ) external view returns (IUniswapV2Pair pair) {
        return _pairs[_tokenA][_tokenB][_id];
    }

    function getPair(address _tokenA, address _tokenB) external view returns (IUniswapV2Pair pair) {
        return _pairs[_tokenA][_tokenB][0];
    }

    function getPair(address _tokenA, address _tokenB, uint256 _id) external view returns (IUniswapV2Pair pair) {
        return _pairs[_tokenA][_tokenB][_id];
    }

    /// @dev expected sorted tokens
    function getPairs(address _token0, address _token1) external view returns (IUniswapV2Pair[] memory pairs) {
        uint256 count = _sameTypePairsCount[_token0][_token1];
        pairs = new IUniswapV2Pair[](count);

        for (uint256 i; i < count;) {
            pairs[i] = _pairs[_token0][_token1][i];
            unchecked { i++; }
        }
    }

    function getAllPairs(uint256 _offset, uint256 _limit) external view returns (IUniswapV2Pair[] memory pairs) {
        pairs = new IUniswapV2Pair[](_limit);
        uint256 count = pairs.length;

        unchecked {
            for (uint256 i; i < _limit; i++) {
                uint256 id = _offset + i;

                if (id < count) {
                    pairs[i] = IUniswapV2Pair(allPairs[id]);
                }
            }
        }
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /// @dev because in our AMM we have factory views in router, then for backwards compatibility with Uniswap
    /// we returning self address
    function factory() external view returns (address) {
        return address(this);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) external pure virtual override returns (uint amountB) {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        external
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        external
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    /// @dev requires the initial amount to have already been sent to the first pair
    function _swapIn(uint256 _amountIn, address[] memory _path, address _to)
        internal
        virtual
        returns (uint256[] memory amounts)
    {
        // all below unchecks refer to array index
        unchecked {
            amounts = new uint256[](_path.length / 2);
            uint256 prevAmountIn = _amountIn;
            uint256 count = _path.length - 2;

            for (uint256 i; i < count; i += 2) {
                address to = i + 2 < count ? address(_path[i + 3]) : _to;
                prevAmountIn = ISiloAmmPair(_path[i + 1]).exactInSwap(_path[i], prevAmountIn, to, "");
                amounts[i / 2] = prevAmountIn;
            }
        }
    }

    /// @dev requires the initial amount to have already been sent to the first pair
    /// @param _amounts array of amounts, where first one is IN
    /// @param _path array of addresses, tokens and pairs, because there might be multiple pairs for same tokens
    /// single swap requires 3 addresses: tokenFrom, pair, tokenTo.
    /// @param _to receiver address
    function _swap(uint256[] memory _amounts, address[] memory _path, address _to)
        internal
        virtual
        returns (uint256[] memory amounts)
    {
        // all below unchecks refer to array index
        unchecked {
            amounts = new uint256[](_amounts.length - 1);

            for (uint256 i; i < _path.length - 3; i += 2) {
                (address input, address output) = (_path[i], _path[i + 2]);
                (address token0,) = UniswapV2Library.sortTokens(input, output);
                uint256 amountOut = _amounts[i + 1];

                (uint256 amount0Out, uint256 amount1Out) = input == token0
                    ? (uint256(0), amountOut)
                    : (amountOut, uint256(0));

                address to = i < _path.length - 3 ? address(_path[i + 3]) : _to;
                amounts[i / 2] = IUniswapV2Pair(_path[i + 1]).swap(amount0Out, amount1Out, to, "");
            }
        }
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory _path, address _to) internal virtual {
        for (uint i; i < _path.length - 2; i+=2) {
            (address input, address output) = (_path[i], _path[i + 2]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            IUniswapV2Pair pair = IUniswapV2Pair(_path[i + 1]);
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
                (uint reserve0, uint reserve1,) = pair.getReserves();
                (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
                amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < _path.length - 3 ? _path[i + 3] : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
}
