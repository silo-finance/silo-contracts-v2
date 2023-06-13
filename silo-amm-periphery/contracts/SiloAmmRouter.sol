// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

import "silo-amm-core/contracts/interfaces/ISiloAmmPairFactory.sol";
import "silo-amm-core/contracts/external/interfaces/ISiloOracle.sol";

import "./libraries/UniswapV2Library.sol";
import "./interfaces/NotSupported.sol";


/// @dev based on UniswapV2Router02
contract SiloAmmRouter is NotSupported {
    ISiloAmmPairFactory public immutable FACTORY; // solhint-disable-line var-name-mixedcase
    address public immutable WETH; // solhint-disable-line var-name-mixedcase

    /// @dev creator => token0 => token1 => pair
    mapping(address => mapping(address => mapping(address => IUniswapV2Pair))) internal _pairs;
    mapping(address => mapping(address => IUniswapV2Pair[])) internal _sameTypePairs;
    address[] public allPairs;

    modifier ensure(uint deadline) {
        if (deadline < block.timestamp) revert UNISWAPV2_ROUTER_EXPIRED();
        _;
    }

    constructor(ISiloAmmPairFactory _factory, address _weth) {
        // TODO ping
        FACTORY = _factory;
        WETH = _weth;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    /// @dev sorted tokens
    function createPair(
        address _token0,
        ISiloOracle _oracle0,
        address _token1,
        ISiloOracle _oracle1,
        IAmmPriceModel.AmmPriceConfig memory _config,
        address _feeTo
    )
        external
        returns (IUniswapV2Pair pair)
    {
        // TODO if (!siloRepository.isSilo(msg.sender)) revert OnlySilo();

        // this will never happen, as request comming from silo
        // if (_tokenA == _tokenB) revert IDENTICAL_ADDRESSES();

        // this will never happen, as request comming from silo
        // if (token0 == address(0)) revert ZERO_ADDRESS();

        // single check is sufficient
        if (address(_pairs[msg.sender][_token0][_token1]) != address(0)) revert PAIR_EXISTS();

        pair = FACTORY.createPair(msg.sender, _token0, _token1, _feeTo, _oracle0, _oracle1, _config);

        _pairs[msg.sender][_token0][_token1] = pair;
        _pairs[msg.sender][_token1][_token0] = pair;
        _sameTypePairs[_token0][_token1].push(pair);

        allPairs.push(address(pair));

        uint256 length = allPairs.length;

        // UniswapV2 compatible event
        emit PairCreated(_token0, _token1, pair, length);
        emit PairCreated(_token0, _token1, pair, msg.sender, length);
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = UniswapV2Library.getAmountsOut(amountIn, path);
        unchecked {
            if (amounts[amounts.length - 1] < amountOutMin) revert UNISWAPV2_ROUTER_INSUFFICIENT_OUTPUT_AMOUNT();
        }
        TransferHelper.safeTransferFrom(path[0], msg.sender, path[1], amounts[0]);
        _swap(amounts, path, to);
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

        TransferHelper.safeTransferFrom(path[0], msg.sender, path[1], amounts[0]);
        _swap(amounts, path, to);
    }

    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        if (path[0] != WETH) revert UNISWAPV2_ROUTER_INVALID_PATH();

        amounts = UniswapV2Library.getAmountsOut(msg.value, path);
        if (amounts[amounts.length - 1] < amountOutMin) revert UNISWAPV2_ROUTER_INSUFFICIENT_OUTPUT_AMOUNT();

        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(path[1], amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        unchecked {
            if (path[path.length - 1] != WETH) revert UNISWAPV2_ROUTER_INVALID_PATH();

            amounts = UniswapV2Library.getAmountsIn(amountOut, path);
            if (amounts[0] > amountInMax) revert UNISWAPV2_ROUTER_EXCESSIVE_INPUT_AMOUNT();

            TransferHelper.safeTransferFrom(path[0], msg.sender, path[1], amounts[0]);
            _swap(amounts, path, address(this));
            IWETH(WETH).withdraw(amounts[amounts.length - 1]);
            TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
        }
    }

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        unchecked {
            if (path[path.length - 1] != WETH) revert UNISWAPV2_ROUTER_INVALID_PATH();

            amounts = UniswapV2Library.getAmountsOut(amountIn, path);
            if (amounts[amounts.length - 1] < amountOutMin) revert UNISWAPV2_ROUTER_INSUFFICIENT_OUTPUT_AMOUNT();

            TransferHelper.safeTransferFrom(
                path[0], msg.sender, path[1], amounts[0]
            );
            _swap(amounts, path, address(this));
            IWETH(WETH).withdraw(amounts[amounts.length - 1]);
            TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
        }
    }

    function swapETHForExactTokens(uint _amountOut, address[] calldata _path, address _to, uint _deadline)
        external
        virtual
        override
        payable
        ensure(_deadline)
        returns (uint[] memory amounts)
    {
        if (_path[0] != WETH) revert UNISWAPV2_ROUTER_INVALID_PATH();

        amounts = UniswapV2Library.getAmountsIn(_amountOut, _path);
        if (amounts[0] > msg.value) revert UNISWAPV2_ROUTER_EXCESSIVE_INPUT_AMOUNT();

        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(_path[1], amounts[0]));
        _swap(amounts, _path, _to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(path[0], msg.sender, path[1], amountIn);
        uint lastId;
        unchecked { lastId = path.length - 1; }
        uint balanceBefore = IERC20(path[lastId]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);

        if (IERC20(path[lastId]).balanceOf(to) - balanceBefore < amountOutMin)
            revert UNISWAPV2_ROUTER_INSUFFICIENT_OUTPUT_AMOUNT();
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        if (path[0] != WETH) revert UNISWAPV2_ROUTER_INVALID_PATH();

        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(path[1], amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);

        if (IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore < amountOutMin)
            revert UNISWAPV2_ROUTER_INSUFFICIENT_OUTPUT_AMOUNT();
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
    {
        if (path[path.length - 1] != WETH) revert UNISWAPV2_ROUTER_INVALID_PATH();

        TransferHelper.safeTransferFrom(path[0], msg.sender, path[1], amountIn);
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        if (amountOut < amountOutMin) revert UNISWAPV2_ROUTER_INSUFFICIENT_OUTPUT_AMOUNT();

        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
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
        address _silo,
        address _tokenA,
        address _tokenB
    ) external view returns (IUniswapV2Pair pair) {
        return _pairs[_silo][_tokenA][_tokenB];
    }

    function getPair(address _tokenA, address _tokenB) external view returns (IUniswapV2Pair pair) {
        return _pairs[address(0)][_tokenA][_tokenB];
    }

    function getPair(address _tokenA, address _tokenB, address _silo) external view returns (IUniswapV2Pair pair) {
        return _pairs[_silo][_tokenA][_tokenB];
    }

    /// @dev expected sorted tokens
    function getPairs(address _tokenA, address _tokenB) external view returns (IUniswapV2Pair[] memory) {
        (address token0, address token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA); // gas??
        return _sameTypePairs[token0][token1];
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

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory _amounts, address[] memory _path, address _to) internal virtual {
        unchecked {
            for (uint i; i < _path.length - 2; i+=2) {
                (address input, address output) = (_path[i], _path[i + 2]);
                (address token0,) = UniswapV2Library.sortTokens(input, output);
                uint amountOut = _amounts[i + 1];
                (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
                address to = i < _path.length - 3 ? address(_path[i + 3]) : _to;
                IUniswapV2Pair(_path[i+1]).swap(amount0Out, amount1Out, to, new bytes(0));
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
