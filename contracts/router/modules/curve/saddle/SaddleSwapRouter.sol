// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {RouterImmutables, RouterParameters} from '../../../base/RouterImmutables.sol';
import {Payments} from '../../Payments.sol';
import {Permit2Payments} from '../../Permit2Payments.sol';
import {Constants} from '../../../libraries/Constants.sol';
import {SafeCastLib} from '../../../../libraries/SafeCastLib.sol';
import {UniERC20} from '../../../../libraries/UniERC20.sol';
import {ISaddlePool} from '../../../interfaces/external/ISaddlePool.sol';

/// @title Router for Saddle Trades
contract SaddleSwapRouter is Permit2Payments {
    using SafeCastLib for uint256;
    using SafeCastLib for int256;
    using UniERC20 for address;

    struct SaddleParams {
        // swapParams[0] = from index i
        // swapParams[1] = to index j
        // swapParams[2] = swap type
        /// The swapType is
        /// 1 for a stableswap `exchange`,
        /// 2 for stableswap `exchange_underlying`,
        /// 3-6 for wrapped coin (don't accept underlying for lending or fake pool) -> LP token "exchange" (actually `addLiquidity`),
        /// 7 for LP token -> wrapped coin (don't accept underlying for lending pool) "exchange" (actually `remove_liquidity_one_coin`)
        uint256[3] swapParams;
        address fromToken;
        address toToken;
        address pool;
    }

    constructor(RouterParameters memory params) RouterImmutables(params) {}

    function _parseSaddleParams(
        SaddleParams memory params,
        uint256 i,
        uint256[3][] memory swapParams,
        address[] memory path
    ) internal pure returns (SaddleParams memory) {
        params.swapParams = swapParams[i / 2];
        params.fromToken = path[i];
        params.toToken = path[i + 2];
        params.pool = path[i + 1];
        return params;
    }

    function _saddleSwap(
        uint256[3][] memory swapParams,
        uint256 amountIn,
        address recipient,
        address[] memory path
    ) internal returns (uint256 amountOut) {
        amountOut = amountIn;
        if (swapParams.length != ((path.length - 1) / 2)) {
            revert('SaddleInvalidPath');
        }

        SaddleParams memory params;

        for (uint256 i = 0; i < path.length - 1; i = i + 2) {
            params = _parseSaddleParams(params, i, swapParams, path);
            params.fromToken.uniApproveMax(params.pool, amountOut);
            uint256 bfBalance = params.toToken.uniBalanceOf(address(this));

            // TODO could be changed to switch operation in assembly for gas optimization
            // binary search for the correct swap function
            if (params.swapParams[2] == 1) {
                // saddle pool exchange
                if (
                    ISaddlePool(params.pool).getToken(params.swapParams[0].toUint8()) != params.fromToken ||
                    ISaddlePool(params.pool).getToken(params.swapParams[1].toUint8()) != params.toToken
                ) {
                    revert('SaddleInvalidPath');
                }
                ISaddlePool(params.pool).swap(
                    params.swapParams[0].toUint8(),
                    params.swapParams[1].toUint8(),
                    amountOut,
                    1,
                    type(uint256).max
                );
            } else if (params.swapParams[2] == 2) {
                // saddle pool exchange_underlying
                ISaddlePool(params.pool).swapUnderlying(
                    params.swapParams[0].toUint8(),
                    params.swapParams[1].toUint8(),
                    amountOut,
                    1,
                    type(uint256).max
                );
            } else if (params.swapParams[2] == 3) {
                if (
                    ISaddlePool(params.pool).getToken(params.swapParams[0].toUint8()) != params.fromToken ||
                    getLPToken(params.pool) != params.toToken
                ) {
                    revert('SaddleInvalidPath');
                }
                // ISaddlePool add liquidity
                uint256[] memory amounts = new uint256[](2);
                amounts[params.swapParams[0]] = amountOut;
                ISaddlePool(params.pool).addLiquidity(amounts, 1, type(uint256).max);
            } else if (params.swapParams[2] == 4) {
                if (
                    ISaddlePool(params.pool).getToken(params.swapParams[0].toUint8()) != params.fromToken ||
                    getLPToken(params.pool) != params.toToken
                ) {
                    revert('SaddleInvalidPath');
                }
                // ISaddlePool add liquidity
                uint256[] memory amounts = new uint256[](3);

                amounts[params.swapParams[0]] = amountOut;
                ISaddlePool(params.pool).addLiquidity(amounts, 1, type(uint256).max);
            } else if (params.swapParams[2] == 5) {
                if (
                    ISaddlePool(params.pool).getToken(params.swapParams[0].toUint8()) != params.fromToken ||
                    getLPToken(params.pool) != params.toToken
                ) {
                    revert('SaddleInvalidPath');
                }
                // ISaddlePool add liquidity
                uint256[] memory amounts = new uint256[](4);

                amounts[params.swapParams[0]] = amountOut;
                ISaddlePool(params.pool).addLiquidity(amounts, 1, type(uint256).max);
            } else if (params.swapParams[2] == 6) {
                if (
                    ISaddlePool(params.pool).getToken(params.swapParams[0].toUint8()) != params.fromToken ||
                    getLPToken(params.pool) != params.toToken
                ) {
                    revert('SaddleInvalidPath');
                }
                // ISaddlePool add liquidity
                uint256[] memory amounts = new uint256[](5);

                amounts[params.swapParams[0]] = amountOut;
                ISaddlePool(params.pool).addLiquidity(amounts, 1, type(uint256).max);
            } else if (params.swapParams[2] == 7) {
                if (
                    getLPToken(params.pool) != params.fromToken ||
                    ISaddlePool(params.pool).getToken(params.swapParams[1].toUint8()) != params.toToken
                ) {
                    revert('SaddleInvalidPath');
                }
                // Remove liquidity one coin in 3 Coins pool
                // the numbder of getToken doesn't matter here
                ISaddlePool(params.pool).removeLiquidityOneToken(
                    amountOut,
                    params.swapParams[1].toUint8(),
                    1,
                    type(uint256).max
                );
            }
            amountOut = params.toToken.uniBalanceOf(address(this)) - bfBalance;
        }
        payOrPermit2Transfer(path[path.length - 1], address(this), recipient, amountOut);
    }

    function getLPToken(address pool) internal view returns (address lpToken) {
        (, , , , , , lpToken) = ISaddlePool(pool).swapStorage();
    }

    /// @notice Perform a saddle exact input swap
    /// @dev saddle pool must be approved to spend the input token
    /// @param amountIn The amount of input token.
    //   /// @param amountOutMin The minimum amount received after the final swap.
    /// @param swapParams 2D array of [i, j, swapType] where i and j are the correct index values
    /// for each pool. i, j are 8 when they are the LP token of the pool(including meta underlying pool) as the max coin in saddle is 8(max index is 7).
    /// The swapType is
    /// The swapType is
    /// 1 for a stableswap `exchange`,
    /// 2 for stableswap `exchange_underlying`,
    /// 3-6 for wrapped coin (don't accept underlying for lending or fake pool) -> LP token "exchange" (actually `addLiquidity`),
    /// 7 for LP token -> wrapped coin (don't accept underlying for lending pool) "exchange" (actually `remove_liquidity_one_coin`)
    /// @param recipient The recipient of the output tokens
    /// @param payer The address that will be paying the input
    /// @param path The path of the trade as an array of token-pool-token + [-pool-token] addresses
    /// @return amountOut The amount of output token
    function saddleSwapExactInput(
        uint256 amountIn,
        // uint256 amountOutMin,
        uint256[3][] memory swapParams,
        address recipient,
        address payer,
        address[] memory path
    ) public payable returns (uint256 amountOut) {
        // verify path
        if (path.length < 3 || swapParams.length != (path.length - 1) / 2 || path.length % 2 == 0)
            revert('SaddleInvalidPath');
        if (
            amountIn != Constants.ALREADY_PAID // amountIn of 0 to signal that the pair already has the tokens
        ) {
            payOrPermit2Transfer(path[0], payer, address(this), amountIn);
        }

        address tokenOut = path[path.length - 1];
        uint256 balanceBefore = tokenOut.uniBalanceOf(recipient);

        _saddleSwap(swapParams, amountIn, recipient, path);

        amountOut = tokenOut.uniBalanceOf(recipient) - balanceBefore;
        if (amountOut == 0) revert('SaddleTooLittleReceived');
    }
}
