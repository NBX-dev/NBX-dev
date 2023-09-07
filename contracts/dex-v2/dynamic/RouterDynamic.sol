// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@matterlabs/signature-checker/contracts/SignatureChecker.sol";
import "@openzeppelin/contracts-4.8/access/Ownable.sol";

import '../interfaces/IFactoryDynamic.sol';
import '../libraries/TransferHelper.sol';
import '../interfaces/IPairDynamic.sol';

import '../interfaces/IRouterDynamic.sol';
import '../libraries/SafeMath.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IWETH.sol';


contract RouterDynamic is IRouterDynamic, Ownable {
    using SafeMath for uint;

    address public immutable override factory;
    address public WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, ': EXPIRED');
        _;
    }

    constructor(address _factory, address _weth) {
        factory = _factory;
        WETH = _weth;
    }

    receive() external payable {
        require(msg.sender == address(WETH), "::receive callback not WETH"); // only accept ETH via fallback from the WETH contract
    }
    
    fallback() external payable { }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        uint feeType,
        bool stable
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (IFactoryDynamic(factory).getPair(tokenA, tokenB, stable) == address(0)) {
            IFactoryDynamic(factory).createPair(tokenA, tokenB, feeType, stable);
        }
        (uint reserveA, uint reserveB) = getReserves(tokenA, tokenB, stable);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, ': INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = quote(amountBDesired, reserveB, reserveA);
                require(amountAOptimal <= amountADesired, ": INSUFFICIENT_OPTIMAL");
                require(amountAOptimal >= amountAMin, ': INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        uint feeType,
        bool stable
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, feeType, stable);
        address pair = pairFor(tokenA, tokenB, stable);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IPairDynamic(pair).mint(to);
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        uint feeType,
        bool stable
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin,
            feeType,
            stable
        );
        address pair = pairFor(token, WETH, stable);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        require(IWETH(WETH).transfer(pair, amountETH), "::addLiquidityETH: FAILED_WETH_TRANSFER");
        liquidity = IPairDynamic(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool stable
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = pairFor(tokenA, tokenB, stable);
        IPairDynamic(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IPairDynamic(pair).burn(to);
        (address token0,) = sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, ': INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, ': INSUFFICIENT_B_AMOUNT');
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool stable
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline,
            stable
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }


    /*
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        bytes memory sig
    ) external returns (uint amountA, uint amountB) {
        address pair = pairFor(tokenA, tokenB, stable);
        {
            uint value = approveMax ? type(uint).max : liquidity;
            IPairDynamic(pair).permit(msg.sender, address(this), value, deadline, sig);
        }

        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline, stable);
    }

    function removeLiquidityETHWithPermit(
        address token,
        bool stable,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bytes memory sig
    ) public returns (uint amountToken, uint amountETH) {
        address pair = pairFor(token, address(WETH), stable);
        IPairDynamic(pair).permit(msg.sender, address(this), liquidity, deadline, sig);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline, stable);
    }
    */


    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool stable
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline,
            stable
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to, bool[] memory stable) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            bool _stable = stable[i];
            (address token0,) = sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? pairFor(output, path[i + 2], stable[i + 1]) : _to;
            IPairDynamic(pairFor(input, output, _stable)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata stable
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        (amounts, , ) = getAmountsOut(amountIn, path, stable);
        require(amounts[amounts.length - 1] >= amountOutMin, ': INSUFFICIENT_OUTPUT_AMOUNT');

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pairFor(path[0], path[1], stable[0]), amounts[0]
        );

        _swap(amounts, path, to, stable);
    }


    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline, bool[] calldata stable)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, ': INVALID_PATH');
        (amounts, , ) = getAmountsOut(msg.value, path, stable);
        require(amounts[amounts.length - 1] >= amountOutMin, ': INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        require(IWETH(WETH).transfer(pairFor(path[0], path[1], stable[0]), amounts[0]), "::swapExactETHForTokens: FAILED_WETH_TRANSFER");
        _swap(amounts, path, to, stable);
    }

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline, bool[] calldata stable)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, ': INVALID_PATH');
        (amounts, , ) = getAmountsOut(amountIn, path, stable);
        require(amounts[amounts.length - 1] >= amountOutMin, ': INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pairFor(path[0], path[1], stable[0]), amounts[0]
        );
        _swap(amounts, path, address(this), stable);
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to, bool[] memory stable) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = sortTokens(input, output);
            IPairDynamic pair = IPairDynamic(pairFor(input, output, stable[i]));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = pair.getAmountOut(amountInput, input);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? pairFor(output, path[i + 2], stable[i + 1]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata stable
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pairFor(path[0], path[1], stable[0]), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to, stable);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            ': INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata stable
    )
        external virtual override payable ensure(deadline)
    {
        require(path[0] == WETH, ': INVALID_PATH');
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        require(IWETH(WETH).transfer(pairFor(path[0], path[1], stable[0]), amountIn), "::swapExactETHForTokens: FAILED_WETH_TRANSFER");
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to, stable);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            ': INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata stable
    )
        external virtual override ensure(deadline)
    {
        require(path[path.length - 1] == WETH, ': INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pairFor(path[0], path[1], stable[0]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this), stable);
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, ': INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }


    function getPairInfo(address[] memory path, bool stable) public view
    returns(address tokenA, address tokenB, address pair, uint reserveA, uint reserveB, uint fee)
    {
        (tokenA, tokenB) = sortTokens(path[0], path[1]);
        (reserveA, reserveB) = getReserves(path[0], path[1], stable);
        pair = pairFor(path[0], path[1], stable);
        fee = IPairDynamic(pair).pairFee();
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Library: ZERO_ADDRESS');
    }

    // fetches pair address for tokens from factory
    function pairFor(address tokenA, address tokenB, bool stable) public view returns (address pair) {
        pair = IFactoryDynamic(factory).getPair(tokenA, tokenB, stable);
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairForIndirect(address tokenA, address tokenB, bool stable) public view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
            hex'ff',
            factory,
            keccak256(abi.encodePacked(token0, token1, stable)),
            IFactoryDynamic(factory).pairCodeHash() // init code hash
        )))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address tokenA, address tokenB, bool stable) public view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IPairDynamic(pairFor(tokenA, tokenB, stable)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) public pure returns (uint amountB) {
        require(amountA > 0, 'Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB).div(reserveA);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) public view returns (uint amountOut, bool stable, uint fee) {
        address pair = pairFor(tokenIn, tokenOut, true);
        uint amountStable;
        uint amountVolatile;
        uint feeStable;
        uint feeVolatile;
        if (pair != address(0)) {
          amountStable = IPairDynamic(pair).getAmountOut(amountIn, tokenIn);
          feeStable = IPairDynamic(pair).pairFee();
        }
        pair = pairFor(tokenIn, tokenOut, false);
        if (pair != address(0)) {
          amountVolatile = IPairDynamic(pair).getAmountOut(amountIn, tokenIn);
          feeVolatile = IPairDynamic(pair).pairFee();
        }
        return amountStable > amountVolatile ? (amountStable, true, feeStable) : (amountVolatile, false, feeVolatile);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOutExpanded(uint amountIn, address[] memory path) public view returns (uint[] memory amounts, bool[] memory stable, uint[] memory fees) {
        require(path.length >= 2, 'Library: INVALID_PATH');
        amounts = new uint[](path.length);
        stable = new bool[](path.length);
        fees = new uint[](path.length);

        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
          (uint _am, bool _stable, uint _fee) = getAmountOut(amounts[i], path[i], path[i + 1]);
          amounts[i+1] = _am;
          stable[i] = _stable;
          fees[i] = _fee;
        }
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(uint amountIn, address[] memory path, bool[] memory stable) public view returns (uint[] memory amounts, bool[] memory _stable, uint[] memory fees) {
        require(path.length >= 2, 'Library: INVALID_PATH');
        amounts = new uint[](path.length);
        fees = new uint[](path.length);
        _stable = new bool[](path.length);

        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
          address pair = pairFor(path[i], path[i + 1], stable[i]);
          if (pair != address(0)) {
            amounts[i+1] = IPairDynamic(pair).getAmountOut(amounts[i], path[i]);
            _stable[i] = stable[i];
            fees[i] = IPairDynamic(pair).pairFee();
          }
        }
    }
}