// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {RouterImmutables, RouterParameters} from '../../../base/RouterImmutables.sol';
import {Payments} from '../../Payments.sol';
import {Permit2Payments} from '../../Permit2Payments.sol';
import {Constants} from '../../../libraries/Constants.sol';
import {SafeCastLib} from '../../../../libraries/SafeCastLib.sol';
import {UniERC20} from '../../../../libraries/UniERC20.sol';
import {CurvePool, AddressProvider, CurveCryptoRegsitry, CurveRegistry, CryptoPool, CryptoPoolETH, LendingBasePoolMetaZap, CryptoMetaZap, BasePool2Coins, CryptoMetaZap, BasePool2Coins, BasePool3Coins, LendingBasePool3Coins, CryptoBasePool3Coins, BasePool4Coins, BasePool5Coins} from '../../../interfaces/external/ICurvePool.sol';

// import 'forge-std/console.sol';

/// @title Router for Curve v2 Trades
contract CurveSwapRouter is Permit2Payments {
    using SafeCastLib for uint256;
    using SafeCastLib for int256;
    using UniERC20 for address;

    struct CurveParams {
        // swapParams[0] = from index i
        // swapParams[1] = to index j
        // swapParams[2] = swap type
        /// The swapType is
        /// 1 for a stableswap `exchange`,
        /// 2 for stableswap `exchange_underlying`,
        /// 3 for a cryptoswap `exchange`,
        /// 4 for a cryptoswap `exchange_underlying`,
        /// 5-9 for wrapped coin (don't accept underlying for lending or fake pool) -> LP token "exchange" (actually `add_liquidity`),
        /// 10-12 for LP token -> wrapped coin (don't accept underlying for lending pool) "exchange" (actually `remove_liquidity_one_coin`)
        uint256[3] swapParams;
        address fromToken;
        address toToken;
        address pool;
        bool isETHUsed;
    }

    constructor(RouterParameters memory params) RouterImmutables(params) {}

    function _parseCurveParams(
        CurveParams memory params,
        uint256 i,
        uint256[3][] memory swapParams,
        address[] memory path,
        address weth9
    ) internal pure returns (CurveParams memory) {
        params.isETHUsed = false;
        params.swapParams = swapParams[i / 2];

        if (path[i] == Constants.ETH) {
            params.isETHUsed = true;
            if (
                params.swapParams[2] == 2 ||
                params.swapParams[2] == 3 ||
                params.swapParams[2] == 4 ||
                params.swapParams[2] == 12
            ) {
                params.fromToken = weth9;
            } else {
                params.fromToken = Constants.ETH_ADDRESS;
            }
        } else {
            params.fromToken = path[i];
        }

        if (path[i + 2] == Constants.ETH) {
            params.isETHUsed = true;
            if (
                params.swapParams[2] == 2 ||
                params.swapParams[2] == 3 ||
                params.swapParams[2] == 4 ||
                params.swapParams[2] == 12
            ) {
                params.toToken = weth9;
            } else {
                params.toToken = Constants.ETH_ADDRESS;
            }
        } else {
            params.toToken = path[i + 2];
        }
        params.pool = path[i + 1];
        return params;
    }

    function _curveSwap(
        uint256[3][] memory swapParams,
        uint256 amountIn,
        address recipient,
        address[] memory path
    ) internal returns (uint256 amountOut) {
        amountOut = amountIn;
        address weth9 = address(WETH9);
        if (swapParams.length != ((path.length - 1) / 2)) {
            revert('CurveInvalidPath');
        }

        CurveParams memory params;

        for (uint256 i = 0; i < path.length - 1; i = i + 2) {
            params = _parseCurveParams(params, i, swapParams, path, weth9);
            params.fromToken.uniApproveMax(params.pool, amountOut);
            uint256 bfBalance = params.toToken.uniBalanceOf(address(this));

            // TODO could be changed to switch operation in assembly for gas optimization
            // binary search for the correct swap function
            if (params.swapParams[2] == 1) {
                // curve pool exchange
                if (
                    CurvePool(params.pool).coins(params.swapParams[0]) != params.fromToken ||
                    CurvePool(params.pool).coins(params.swapParams[1]) != params.toToken
                ) {
                    revert('CurveInvalidPath');
                }
                CurvePool(params.pool).exchange{value: params.fromToken == Constants.ETH ? amountOut : 0}(
                    int256(params.swapParams[0]).toInt128(),
                    int256(params.swapParams[1]).toInt128(),
                    amountOut,
                    1
                );
            } else if (params.swapParams[2] == 2) {
                // curve pool exchange_underlying
                if (
                    CurvePool(params.pool).underlying_coins(params.swapParams[0]) != params.fromToken ||
                    CurvePool(params.pool).underlying_coins(params.swapParams[1]) != params.toToken
                ) {
                    revert('CurveInvalidPath');
                }
                CurvePool(params.pool).exchange_underlying{value: params.fromToken == Constants.ETH ? amountOut : 0}(
                    int256(params.swapParams[0]).toInt128(),
                    int256(params.swapParams[1]).toInt128(),
                    amountOut,
                    1
                );
            } else if (params.swapParams[2] == 3) {
                // as most of trades execute exchange/underlying, we can save gas by ordering the check
                // crypto pool exchange
                if (
                    CryptoPool(params.pool).coins(params.swapParams[0]) != params.fromToken ||
                    CryptoPool(params.pool).coins(params.swapParams[1]) != params.toToken
                ) {
                    revert('CurveInvalidPath');
                }

                if (params.isETHUsed) {
                    CryptoPoolETH(params.pool).exchange{value: params.fromToken == weth9 ? amountOut : 0}(
                        params.swapParams[0],
                        params.swapParams[1],
                        amountOut,
                        1,
                        true
                    );
                } else {
                    // console.log('CryptoPool exchange entry');

                    CryptoPool(params.pool).exchange(params.swapParams[0], params.swapParams[1], amountOut, 1);
                    // console.log('CryptoPool exchange executed');
                }
            } else if (params.swapParams[2] == 4) {
                // crypto pool exchange_underlying (just using ETH as underlying -> redundant right now)

                CryptoPool(params.pool).exchange_underlying{value: params.fromToken == weth9 ? amountOut : 0}(
                    params.swapParams[0],
                    params.swapParams[1],
                    amountOut,
                    1
                );
            } else if (params.swapParams[2] == 5) {
                // BasePool2Coins add liquidity
                uint256[2] memory amounts;
                amounts[params.swapParams[0]] = amountOut;
                // // console.log('basepool2coin addliquidity entry');
                BasePool2Coins(params.pool).add_liquidity(amounts, 1);
                // // console.log('basepool2coin addliquidity executed');
            } else if (params.swapParams[2] == 6) {
                // BasePool3Coins add liquidity
                uint256[3] memory amounts;
                amounts[params.swapParams[0]] = amountOut;
                BasePool3Coins(params.pool).add_liquidity(amounts, 1);
            } else if (params.swapParams[2] == 7) {
                // LendingBasePool3Coins add liquidity
                uint256[3] memory amounts;
                amounts[params.swapParams[0]] = amountOut;
                // no underlying you should deposit the token first to aave if you want to use add_liquidity
                LendingBasePool3Coins(params.pool).add_liquidity(amounts, 0, false);
            } else if (params.swapParams[2] == 8) {
                // BasePool4Coins add liquidity
                uint256[4] memory amounts;
                amounts[params.swapParams[0]] = amountOut;
                BasePool4Coins(params.pool).add_liquidity(amounts, 1);
            } else if (params.swapParams[2] == 9) {
                // BasePool5Coins add liquidity
                uint256[5] memory amounts;
                amounts[params.swapParams[0]] = amountOut;
                BasePool5Coins(params.pool).add_liquidity(amounts, 1);
            } else if (params.swapParams[2] == 10) {
                // Remove liquidity one coin in 3 Coins pool
                // the numbder of coins doesn't matter here
                BasePool3Coins(params.pool).remove_liquidity_one_coin(
                    amountOut,
                    int256(params.swapParams[1]).toInt128(),
                    1
                );
            } else if (params.swapParams[2] == 11) {
                // no underlying you should withdraw the underlying token from atoken from aave if you want to use remove_liquidity_one_coin
                LendingBasePool3Coins(params.pool).remove_liquidity_one_coin(
                    amountOut,
                    int256(params.swapParams[1]).toInt128(),
                    1,
                    false
                );
            } else if (params.swapParams[2] == 12) {
                if (
                    CryptoPool(params.pool).token() != params.fromToken ||
                    CryptoPool(params.pool).coins(params.swapParams[1]) != params.toToken
                ) {
                    revert('CurveInvalidPath');
                }
                CryptoBasePool3Coins(params.pool).remove_liquidity_one_coin(amountOut, params.swapParams[1], 1);
            }
            // // console.log('bfBalance ', bfBalance);
            amountOut = params.toToken.uniBalanceOf(address(this)) - bfBalance;
            // // console.log('amountOut ', amountOut);
        }
        payOrPermit2Transfer(path[path.length - 1], address(this), recipient, amountOut);
    }

    /// @notice Perform a curve v1/v2 exact input swap
    /// @dev curve pool and curve crypto pools must be approved to spend the input token
    /// For crypto pool path with ETH, though it is described in WETH but it transfers ETH
    /// To Use curve swap with ETH, the ETH must be unwrapped before calling it
    /// @param amountIn The amount of input token.
    //  /// @param amountOutMin The minimum amount received after the final swap.
    /// @param swapParams 2D array of [i, j, swapType] where i and j are the correct index values
    /// for each pool. i, j are 8 when they are the LP token of the pool(including meta underlying pool) as the max coin in curve is 8(max index is 7).
    /// The swapType is
    /// 1 for a stableswap `exchange`,
    /// 2 for stableswap `exchange_underlying`,
    /// 3 for a cryptoswap `exchange`,
    /// 4 for a cryptoswap `exchange_underlying`,
    /// 5-9 for wrapped coin (don't accept underlying for lending or fake pool) -> LP token "exchange" (actually `add_liquidity`),
    /// 10-12 for LP token -> wrapped coin (don't accept underlying for lending pool) "exchange" (actually `remove_liquidity_one_coin`)
    /// @param recipient The recipient of the output tokens
    /// @param payer The address that will be paying the input
    /// @param path The path of the trade as an array of token-pool-token + [-pool-token] addresses
    /// @return amountOut The amount of output token
    function curveSwapExactInput(
        uint256 amountIn,
        // uint256 amountOutMin,
        uint256[3][] memory swapParams,
        address recipient,
        address payer,
        address[] memory path
    ) public payable returns (uint256 amountOut) {
        // verify path
        if (path.length < 3 || swapParams.length != (path.length - 1) / 2 || path.length % 2 == 0)
            revert('CurveInvalidPath');
        if (
            amountIn != Constants.ALREADY_PAID // amountIn of 0 to signal that the pair already has the tokens
        ) {
            if (path[0] != Constants.ETH) {
                payOrPermit2Transfer(path[0], payer, address(this), amountIn);
            }
        }

        address tokenOut = path[path.length - 1];
        uint256 balanceBefore = tokenOut.uniBalanceOf(recipient);

        _curveSwap(swapParams, amountIn, recipient, path);

        amountOut = tokenOut.uniBalanceOf(recipient) - balanceBefore;
        if (amountOut == 0) revert('CurveTooLittleReceived');
    }
}
