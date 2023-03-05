// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {RouterImmutables, RouterParameters} from '../../base/RouterImmutables.sol';
import {Payments} from '../Payments.sol';
import {Permit2Payments} from '../Permit2Payments.sol';
import {Constants} from '../../libraries/Constants.sol';
import {UniERC20} from '../../../libraries/UniERC20.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {IDODOV2, IDODOV1, IDODOSellHelper} from '../../interfaces/external/IDODO.sol';

/// @title Router for Dodo v2 Trades
contract DodoSwapRouter is Permit2Payments {
    using UniERC20 for address;

    constructor(RouterParameters memory params) RouterImmutables(params) {}

    function _getBaseAndQuote(address pair) private view returns (address base, address quote) {
        base = IDODOV1(pair)._BASE_TOKEN_();
        quote = IDODOV1(pair)._QUOTE_TOKEN_();
    }

    function _dodoV1SellBaseSwap(uint256 amountIn, address pair) private returns (uint256 amountOut) {
        (address curBase, ) = _getBaseAndQuote(pair);

        curBase.uniApproveMax(pair, amountIn);
        amountOut = IDODOV1(pair).sellBaseToken(amountIn, 0, '');
    }

    function _dodoV1SellQuoteSwap(uint256 amountIn, address pair) private returns (uint256 amountOut) {
        // sellQuoteToken
        (, address curQuote) = _getBaseAndQuote(pair);
        curQuote.uniApproveMax(pair, amountIn);
        amountOut = IDODOSellHelper(DODO_V1_SELL_HELPER).querySellQuoteToken(pair, amountIn);
        IDODOV1(pair).buyBaseToken(amountOut, amountIn, '');
    }

    function _dodoV2SellBaseSwap(
        uint256 amountIn,
        address recipient,
        address pair,
        uint8 receivedFlag
    ) private returns (uint256 amountOut) {
        (address curBase, ) = _getBaseAndQuote(pair);
        if (receivedFlag == 0) {
            payOrPermit2Transfer(curBase, address(this), pair, amountIn);
        }
        amountOut = IDODOV2(pair).sellBase(recipient);
    }

    function _dodoV2SellQuoteSwap(
        uint256 amountIn,
        address recipient,
        address pair,
        uint8 receivedFlag
    ) private returns (uint256 amountOut) {
        (, address curQuote) = _getBaseAndQuote(pair);
        if (receivedFlag == 0) {
            payOrPermit2Transfer(curQuote, address(this), pair, amountIn);
        }
        amountOut = IDODOV2(pair).sellQuote(recipient);
    }

    function _dodoSwap(
        uint256 directions,
        uint256 amountIn,
        uint8[] memory versions,
        address[] memory dodoPairs,
        address recipient
    ) private returns (uint256 amountOut) {
        amountOut = amountIn;

        uint8 receivedFlag = 1;
        for (uint256 i = 0; i < dodoPairs.length; i++) {
            if (i == dodoPairs.length - 1) {
                // transfer to receipient ultimately
                if (directions & 1 == 0) {
                    // sellBase
                    if (versions[i] == 2) {
                        // DodoV2
                        amountOut = _dodoV2SellBaseSwap(amountOut, recipient, dodoPairs[i], receivedFlag);
                    } else if (versions[i] == 1) {
                        // DodoV1
                        amountOut = _dodoV1SellBaseSwap(amountOut, dodoPairs[i]);
                    } else {
                        revert('DodoInvalidVersion');
                    }
                } else {
                    // sellQuote
                    if (versions[i] == 2) {
                        // DodoV2
                        amountOut = _dodoV2SellQuoteSwap(amountOut, recipient, dodoPairs[i], receivedFlag);
                    } else if (versions[i] == 1) {
                        // DodoV1
                        amountOut = _dodoV1SellQuoteSwap(amountOut, dodoPairs[i]);
                    } else {
                        revert('DodoInvalidVersion');
                    }
                }
            } else {
                if (directions & 1 == 0) {
                    //sellBase
                    if (versions[i] == 2) {
                        if (versions[i + 1] == 1) {
                            // DodoV2 pair[i] -> address(this) -> DodoV1 pair[i + 1]
                            amountOut = _dodoV2SellBaseSwap(amountOut, address(this), dodoPairs[i], receivedFlag);
                            receivedFlag = 0;
                        } else {
                            // DodoV2 pair[i] -> DodoV2 pair[i + 1]
                            amountOut = _dodoV2SellBaseSwap(amountOut, dodoPairs[i + 1], dodoPairs[i], receivedFlag);
                            receivedFlag = 1;
                        }
                    } else if (versions[i] == 1) {
                        // DodoV1 pair[i] -> address(this) -> DodoV1/V2 pair[i + 1]
                        amountOut = _dodoV1SellBaseSwap(amountOut, dodoPairs[i]);
                        receivedFlag = 0;
                    } else {
                        revert('DodoInvalidVersion');
                    }
                } else {
                    //sellQuote
                    if (versions[i] == 2) {
                        if (versions[i + 1] == 1) {
                            // DodoV2 pair[i] -> address(this) -> DodoV1 pair[i + 1]
                            amountOut = _dodoV2SellQuoteSwap(amountOut, address(this), dodoPairs[i], receivedFlag);
                            receivedFlag = 0;
                        } else {
                            // DodoV2 pair[i] -> DodoV2 pair[i + 1]
                            amountOut = _dodoV2SellQuoteSwap(amountOut, dodoPairs[i + 1], dodoPairs[i], receivedFlag);
                            receivedFlag = 1;
                        }
                    } else if (versions[i] == 1) {
                        // DodoV1 pair[i] -> address(this) -> DodoV1/V2 pair[i + 1]
                        amountOut = _dodoV1SellQuoteSwap(amountOut, dodoPairs[i]);
                        receivedFlag = 0;
                    } else {
                        revert('DodoInvalidVersion');
                    }
                }
            }
            directions = directions >> 1;
        }
    }

    /// @notice Performs a dodo v1/v2 exact input swap
    /// @dev  To Use Dodo swap with ETH, the ETH must be wrapped before calling it
    /// @param amountIn The amount of input tokens for the trade
    //   /// @param amountOutMinimum The minimum desired amount of output tokens
    /// @param directions The directions of the trade as a bitfield 1 means sellQuote and 0 means sellBase \
    /// and the last bit is the direction of the first trade (reverse way)
    /// @param tokenIn The address of input token
    /// @param tokenOut The address of output token
    /// @param dodoPairs The path of the trade as an array of dodo pairs
    /// @param recipient The recipient of the output tokens
    /// @param payer The address that will be paying the input
    /// @param versions The uint8 array of DODO pair pool versions
    function dodoSwapExactInput(
        uint256 amountIn,
        // uint256 amountOutMinimum,
        uint256 directions,
        address tokenIn,
        address tokenOut,
        address[] memory dodoPairs,
        address recipient,
        address payer,
        uint8[] memory versions
    ) public payable returns (uint256 amountOut) {
        if (dodoPairs.length != versions.length) revert('DodoInvalidPath');
        if (dodoPairs.length == 1) {
            if (directions & 1 == 0) {
                // sellBase
                if (
                    IDODOV1(dodoPairs[0])._BASE_TOKEN_() != tokenIn || IDODOV1(dodoPairs[0])._QUOTE_TOKEN_() != tokenOut
                ) revert('DodoInvalidPath');
            } else {
                // sellQuote
                if (
                    IDODOV1(dodoPairs[0])._BASE_TOKEN_() != tokenOut || IDODOV1(dodoPairs[0])._QUOTE_TOKEN_() != tokenIn
                ) revert('DodoInvalidPath');
            }
        } else if (dodoPairs.length > 1) {
            if (directions & (1 << (versions.length - 1)) == 0) {
                // last pair
                // sellBase
                if (IDODOV1(dodoPairs[dodoPairs.length - 1])._QUOTE_TOKEN_() != tokenOut) revert('DodoInvalidPath');
            } else {
                // sellQuote
                if (IDODOV1(dodoPairs[dodoPairs.length - 1])._BASE_TOKEN_() != tokenOut) revert('DodoInvalidPath');
            }
            if (directions & 1 == 0) {
                // the first pair
                // sellBase
                if (IDODOV1(dodoPairs[0])._BASE_TOKEN_() != tokenIn) revert('DodoInvalidPath');
            } else {
                // sellQuote
                if (IDODOV1(dodoPairs[0])._QUOTE_TOKEN_() != tokenIn) revert('DodoInvalidPath');
            }
        } else {
            revert('DodoInvalidPath');
        }

        if (
            amountIn != Constants.ALREADY_PAID // amountIn of 0 to signal that the pair already has the tokens
        ) {
            if (versions[0] == 1) {
                payOrPermit2Transfer(tokenIn, payer, address(this), amountIn);
            } else {
                payOrPermit2Transfer(tokenIn, payer, dodoPairs[0], amountIn);
            }
        }

        uint256 balanceBefore = tokenOut.uniBalanceOf(recipient);

        _dodoSwap(directions, amountIn, versions, dodoPairs, recipient);

        amountOut = tokenOut.uniBalanceOf(recipient) - balanceBefore;
        if (amountOut == 0) revert('DodoTooLittleReceived');
    }
}
