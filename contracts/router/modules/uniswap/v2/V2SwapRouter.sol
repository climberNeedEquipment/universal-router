// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IUniswapV2Pair} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import {IUniswapV2Factory} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import {UniswapV2Library} from './UniswapV2Library.sol';
import {RouterImmutables, RouterParameters} from '../../../base/RouterImmutables.sol';
import {Payments} from '../../Payments.sol';
import {Permit2Payments} from '../../Permit2Payments.sol';
import {Constants} from '../../../libraries/Constants.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {IUniswapV2Viewer} from '../../../../viewer/interfaces/IUniViewer.sol';

/// @title Router for Uniswap v2 Trades
contract UniV2SwapRouter is Permit2Payments {
    constructor(RouterParameters memory params) RouterImmutables(params) {}

    function _v2Swap(
        address[] memory path,
        address recipient,
        address pair
    ) private {
        unchecked {
            if (path.length < 3) revert('UniV2InvalidPath');

            // cached to save on duplicate operations
            (address token0, ) = UniswapV2Library.sortTokens(path[0], path[2]);
            uint256 finalPairIndex = (path.length - 1) / 2;
            uint256 penultimatePairIndex = finalPairIndex - 1;
            for (uint256 i; i < finalPairIndex; i = i + 2) {
                (address input, address output) = (path[i], path[i + 2]);

                (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);

                uint256 amountInput = ERC20(input).balanceOf(pair) - reserveInput;
                uint256 amountOutput = IUniswapV2Viewer(UNISWAP_V2_VIEWER).getAmountOut(
                    path[i + 1],
                    amountInput,
                    reserveInput,
                    reserveOutput
                );
                (uint256 amount0Out, uint256 amount1Out) = input == token0
                    ? (uint256(0), amountOutput)
                    : (amountOutput, uint256(0));

                address nextPair;
                (nextPair, token0) = i < penultimatePairIndex
                    ? UniswapV2Library.pairAndToken0For(path[i + 3], output, path[i + 4])
                    : (recipient, address(0));

                IUniswapV2Pair(pair).swap(amount0Out, amount1Out, nextPair, new bytes(0));
                pair = nextPair;
            }
        }
    }

    /// @notice Performs a Uniswap v2 exact input swap
    /// @dev  To Use Uni swap with ETH, the ETH must be wrapped before calling it
    /// @param recipient The recipient of the output tokens
    /// @param amountIn The amount of input tokens for the trade
    //   /// @param amountOutMinimum The minimum desired amount of output tokens
    /// @param path The path of the trade as an array of token-factory-token + [-factory-token] addresses
    /// @param payer The address that will be paying the input
    /// @return amountOut The amount of output tokens for the trade
    function uniV2SwapExactInput(
        address recipient,
        uint256 amountIn,
        // uint256 amountOutMinimum,
        address[] memory path,
        address payer
    ) public returns (uint256 amountOut) {
        address firstPair = IUniswapV2Factory(path[1]).getPair(path[0], path[2]);

        if (
            amountIn != Constants.ALREADY_PAID // amountIn of 0 to signal that the pair already has the tokens
        ) {
            payOrPermit2Transfer(path[0], payer, firstPair, amountIn);
        }

        ERC20 tokenOut = ERC20(path[path.length - 1]);
        uint256 balanceBefore = tokenOut.balanceOf(recipient);

        _v2Swap(path, recipient, firstPair);

        amountOut = tokenOut.balanceOf(recipient) - balanceBefore;
        if (amountOut == 0) revert('UniV2TooLittleReceived');
    }
}
