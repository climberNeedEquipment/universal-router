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
import {UniERC20} from '../../../../libraries/UniERC20.sol';

interface Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

/// @title Router for Uniswap v2 Trades
contract UniV2RouterSwapAdatper is Permit2Payments {
    using UniERC20 for address;

    constructor(RouterParameters memory params) RouterImmutables(params) {}

    /// @notice Performs a Uniswap v2 exact input swap
    /// @dev  To Use Uni swap with ETH, the ETH must be wrapped before calling it
    /// @param recipient The recipient of the output tokens
    /// @param amountIn The amount of input tokens for the trade
    //  /// @param amountOutMin The minimum desired amount of output tokens
    /// @param path The path of the trade as an array of token-factory-token + [-factory-token] addresses
    /// @param payer The address that will be paying the input
    /// @return amountOut The amount of output tokens for the trade
    function uniV2RouterSwapExactInput(
        address recipient,
        uint256 amountIn,
        // uint256 amountOutMin,
        address router,
        address[] memory path,
        address payer
    ) public returns (uint256 amountOut) {
        if (
            amountIn != Constants.ALREADY_PAID // amountIn of 0 to signal that the pair already has the tokens
        ) {
            payOrPermit2Transfer(path[0], payer, address(this), amountIn);
        }

        if (IUniswapV2Viewer(UNISWAP_V2_VIEWER).isRouter(router) == 0) revert('UniV2InvalidRouter');

        path[0].uniApproveMax(router, amountIn);

        uint256[] memory amountOuts = Router(router).swapExactTokensForTokens(
            amountIn,
            1,
            path,
            recipient,
            type(uint256).max
        );

        amountOut = amountOuts[amountOuts.length - 1];
    }
}
