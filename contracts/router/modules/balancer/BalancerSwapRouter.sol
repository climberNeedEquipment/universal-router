// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {RouterImmutables, RouterParameters} from '../../base/RouterImmutables.sol';
import {Payments} from '../Payments.sol';
import {Permit2Payments} from '../Permit2Payments.sol';
import {Constants} from '../../libraries/Constants.sol';
import {SafeCastLib} from '../../../libraries/SafeCastLib.sol';
import {UniERC20} from '../../../libraries/UniERC20.sol';
import {IBalancerPool, IBalancerVault, IBalancerRegistry} from '../../interfaces/external/IBalancer.sol';

/// @title Router for Balancer v2 Trades
contract BalancerSwapRouter is Permit2Payments {
    using SafeCastLib for uint256;
    using SafeCastLib for int256;
    using UniERC20 for address;

    struct BalancerParams {
        uint256 ethAmount;
        bytes32 poolId;
        address fromToken;
        address toToken;
        uint8 swapParam;
    }

    constructor(RouterParameters memory params) RouterImmutables(params) {}

    function _parseBalancerParams(
        BalancerParams memory params,
        uint256 i,
        bytes32[] memory path
    ) internal pure returns (BalancerParams memory) {
        params.fromToken = _convertBytes32ToAddress(path[i]);
        params.toToken = _convertBytes32ToAddress(path[i + 2]);
        params.poolId = path[i + 1];

        return params;
    }

    function _balancerSwap(
        uint256 amountIn,
        address recipient,
        bytes32[] memory path
    ) internal returns (uint256 amountOut) {
        amountOut = amountIn;
        if (path.length % 2 == 0) {
            revert('BalancerInvalidPath');
        }
        BalancerParams memory params;

        for (uint256 i = 0; i < path.length - 1; i = i + 2) {
            params = _parseBalancerParams(params, i, path);
            uint256 bfBalance = params.toToken.uniBalanceOf(address(this));

            if (params.toToken == Constants.ETH) {
                params.ethAmount = 0;
            }
            if (params.fromToken == Constants.ETH) {
                params.ethAmount = amountIn;
            }

            IBalancerVault.SingleSwap memory singleswap;
            singleswap.poolId = params.poolId;
            singleswap.kind = IBalancerVault.SwapKind.GIVEN_IN;
            singleswap.assetIn = params.fromToken;
            singleswap.assetOut = params.toToken;

            singleswap.amount = amountIn;

            IBalancerVault.FundManagement memory fundManagement;
            fundManagement.sender = address(this);
            fundManagement.fromInternalBalance = false;
            if (i == path.length - 3) {
                fundManagement.recipient = payable(recipient);
            } else {
                fundManagement.recipient = payable(address(this));
            }
            fundManagement.toInternalBalance = false;

            params.fromToken.uniApproveMax(BALANCER_VAULT, amountIn);

            IBalancerVault(BALANCER_VAULT).swap{value: params.ethAmount}(
                singleswap,
                fundManagement,
                1,
                type(uint256).max
            );

            amountOut = params.toToken.uniBalanceOf(address(this)) - bfBalance;
        }
    }

    function balancerSwapExactInput(
        uint256 amountIn,
        // uint256 amountOutMin,
        bytes32[] memory path,
        address recipient,
        address payer
    ) public payable returns (uint256 amountOut) {
        if (
            amountIn != Constants.ALREADY_PAID // amountIn of 0 to signal that the pair already has the tokens
        ) {
            payOrPermit2Transfer(_convertBytes32ToAddress(path[0]), payer, address(this), amountIn);
        }

        address tokenOut = _convertBytes32ToAddress(path[path.length - 1]);
        uint256 balanceBefore = tokenOut.uniBalanceOf(recipient);

        _balancerSwap(amountIn, recipient, path);

        amountOut = tokenOut.uniBalanceOf(recipient) - balanceBefore;
        if (amountOut == 0) revert('BalancerTooLittleReceived');
    }

    function _convertBytes32ToAddress(bytes32 _input) internal pure returns (address) {
        return address(uint160(uint256(_input)));
    }
}
