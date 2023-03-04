// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;
import {AaveAdapter} from '../modules/aave/AaveAdapter.sol';
// import {BalancerSwapRouter} from '../modules/balancer/BalancerSwapRouter.sol';
// import {CurveSwapRouter} from '../modules/curve/original/CurveSwapRouter.sol';
// import {SaddleSwapRouter} from '../modules/curve/saddle/SaddleSwapRouter.sol';
// import {DodoSwapRouter} from '../modules/dodo/DodoSwapRouter.sol';

// import {UniV2RouterSwapAdatper} from '../modules/uniswap/v2/V2RouterSwapAdapter.sol';
// import {UniV2SwapRouter} from '../modules/uniswap/v2/V2SwapRouter.sol';
import {UniV3SwapRouter} from '../modules/uniswap/v3/UniV3SwapRouter.sol';
import {Payments} from '../modules/Payments.sol';
import {RouterImmutables} from '../base/RouterImmutables.sol';
import {Callbacks} from '../base/Callbacks.sol';
import {Commands} from '../libraries/Commands.sol';
import {Constants} from '../libraries/Constants.sol';
import {Recipient} from '../libraries/Recipient.sol';
import {ERC721} from 'solmate/src/tokens/ERC721.sol';
import {ERC1155} from 'solmate/src/tokens/ERC1155.sol';
import {IAllowanceTransfer} from 'permit2/src/interfaces/IAllowanceTransfer.sol';
// import {ICryptoPunksMarket} from '../interfaces/external/ICryptoPunksMarket.sol';
import {BytesLib} from '../modules/uniswap/v3/BytesLib.sol';
import {UniV3Path} from '../modules/uniswap/v3/UniV3Path.sol';
import {RouterParameters} from './RouterImmutables.sol';
// import {ModuleParameters, ModuleImmutables} from './ModuleImmutables.sol';
import {ModuleParameters} from './ModuleImmutables.sol';

// import {console} from 'forge-std/Test.sol';

/// @title Decodes and Executes Commands
/// @notice Called by the UniversalRouterV1 contract to efficiently decode and execute a singular command
contract Dispatcher is
    Payments,
    // UniV2SwapRouter,
    UniV3SwapRouter,
    // AaveAdapter,
    // BalancerSwapRouter,
    // CurveSwapRouter,
    // SaddleSwapRouter,
    // DodoSwapRouter,
    // UniV2RouterSwapAdatper,
    Callbacks
    // RouterImmutables
    // ModuleImmutables
{
    using Recipient for address;
    using UniV3Path for bytes;
    using BytesLib for bytes;
    // using StorageSlot for bytes32;

    error InvalidCommandType(uint256 commandType);
    error InvalidOwnerERC721();
    error InvalidOwnerERC1155();
    error InvalidBatchPath();

    /// @dev The deployed address of UniV2SwapRouter
    address internal UNI_V2_SWAP_ROUTER;

    /// @dev The deployed address of UniV2RouterSwapAdapter
    address internal UNI_V2_ROUTER_SWAP_ADAPTER;

    /// @dev The deployed address of UniV3SwapRouter
    address internal UNI_V3_SWAP_ROUTER;

    /// @dev The deployed address of AaveAdapter
    address internal AAVE_ADAPTER;

    /// @dev The deployed address of BalancerSwapRouter
    address internal BALANCER_SWAP_ROUTER;

    /// @dev The deployed address of CurveSwapRouter
    address internal CURVE_SWAP_ROUTER;

    /// @dev The deployed address of SaddleSwapRouter
    address internal SADDLE_SWAP_ROUTER;

    /// @dev The deployed address of DodoSwapRouter
    address internal DODO_SWAP_ROUTER;

    constructor(RouterParameters memory params, ModuleParameters memory mparams) RouterImmutables(params) {
        UNI_V2_SWAP_ROUTER = mparams.uniV2SwapRouter;
        UNI_V2_ROUTER_SWAP_ADAPTER = mparams.uniV2RouterSwapAdapter;
        UNI_V3_SWAP_ROUTER = mparams.uniV3SwapRouter;
        AAVE_ADAPTER = mparams.aaveAdapter;
        BALANCER_SWAP_ROUTER = mparams.balancerSwapRouter;
        CURVE_SWAP_ROUTER = mparams.curveSwapRouter;
        SADDLE_SWAP_ROUTER = mparams.saddleSwapRouter;
        DODO_SWAP_ROUTER = mparams.dodoSwapRouter;
    }

    /// @notice Decodes and executes the given command with the given inputs
    /// @param commandType The command type to execute
    /// @param inputs The inputs to execute the command with
    /// @dev 2 masks are used to enable use of a nested-if statement in execution for efficiency reasons
    /// @return success True on success of the command, false on failure
    /// @return output The outputs or error messages, if any, from the command = IUniswap
    function dispatch(bytes1 commandType, bytes memory inputs) internal returns (bool success, bytes memory output) {
        uint256 command = uint8(commandType & Commands.COMMAND_TYPE_MASK);

        success = true;

        (address inputToken, address outputToken, uint256 amountOut) = _dispatchWithAmount(command, inputs, 0);
        output = abi.encode(inputToken, outputToken, amountOut);
    }

    struct BatchSwap {
        uint256 accAmountIn;
        uint256 weightSum;
        uint256 amountOut;
        address inputToken;
        address outputToken;
        uint8 IsInit;
    }

    struct TempParams {
        address inputToken;
        address outputToken;
        uint256 amountOut;
    }

    function dispatchWith3DWeights(
        bytes memory commands,
        bytes[] memory inputs,
        uint256 amountIn,
        uint256[] memory initWeights,
        uint256[][][] memory weights
    )
        internal
        returns (
            address inputToken,
            address outputToken,
            uint256 amountOut
        )
    {
        uint256 offSet;
        BatchSwap memory batch3DSwap;
        for (uint256 i; i < initWeights.length; i++) {
            batch3DSwap.weightSum += initWeights[i];
        }

        for (uint256 i; i < weights.length; i++) {
            uint256 eleAmountOut;
            if (i == 0) {
                uint256 spentAmountIn = (amountIn * initWeights[i]) / batch3DSwap.weightSum;
                batch3DSwap.accAmountIn += spentAmountIn;
                (batch3DSwap.inputToken, batch3DSwap.outputToken, eleAmountOut, offSet) = _dispatchWith2DWeights(
                    commands,
                    inputs,
                    spentAmountIn,
                    offSet,
                    weights[i]
                );
                inputToken = batch3DSwap.inputToken;
                outputToken = batch3DSwap.outputToken;

                // console.log(inputToken, outputToken);
            } else if (i == weights.length - 1) {
                (batch3DSwap.inputToken, batch3DSwap.outputToken, eleAmountOut, offSet) = _dispatchWith2DWeights(
                    commands,
                    inputs,
                    amountIn - batch3DSwap.accAmountIn,
                    offSet,
                    weights[i]
                );
                if (batch3DSwap.inputToken != inputToken || batch3DSwap.outputToken != outputToken) {
                    // console.log(i, batch3DSwap.inputToken, batch3DSwap.outputToken);
                    revert InvalidBatchPath();
                }
            } else {
                uint256 spentAmountIn = (amountIn * initWeights[i]) / batch3DSwap.weightSum;
                batch3DSwap.accAmountIn += spentAmountIn;

                (batch3DSwap.inputToken, batch3DSwap.outputToken, eleAmountOut, offSet) = _dispatchWith2DWeights(
                    commands,
                    inputs,
                    spentAmountIn,
                    offSet,
                    weights[i]
                );
                if (batch3DSwap.inputToken != inputToken || batch3DSwap.outputToken != outputToken) {
                    // console.log(i, batch3DSwap.inputToken, batch3DSwap.outputToken);
                    revert InvalidBatchPath();
                }
            }

            amountOut += eleAmountOut;
        }
    }

    /// @notice Decodes and executes the given command with the given amountIn, inputs, and weights
    /// @param commands The command types to execute
    /// @param inputs The inputs to execute the command with
    /// @param amountIn AmountIn for input token
    /// @param offSet The offset to start executing the commands at
    /// @param weights The weights to use for the commands
    /// @dev 2 masks are used to enable use of a nested-if statement in execution for efficiency reasons
    /// @return inputToken The input token for the command
    /// @return outputToken The output token for the command
    /// @return amountOut The amountOut for the command
    function _dispatchWith2DWeights(
        bytes memory commands,
        bytes[] memory inputs,
        uint256 amountIn,
        uint256 offSet,
        uint256[][] memory weights
    )
        internal
        returns (
            address inputToken,
            address outputToken,
            uint256 amountOut,
            uint256 idx
        )
    {
        // weights
        // [[2, 1, 1], [1,1]]
        // 50% A -> UNI   -> B  | 50% -> C
        // 25% A -> SUSHI -> B  | 50% -> C
        // 25% A -> CURVE -> B

        idx = offSet;
        amountOut = amountIn;
        address prevToken;

        for (uint256 i; i < weights.length; i++) {
            BatchSwap memory batchSwap;
            uint256[] memory singleHopWeights = weights[i];

            for (uint256 j; j < weights[i].length; j++) {
                batchSwap.weightSum += singleHopWeights[j];
            }

            for (uint256 j; j < weights[i].length; j++) {
                uint256 command = uint8(commands[idx] & Commands.COMMAND_TYPE_MASK);
                TempParams memory temp;
                if (j == weights[i].length - 1) {
                    (temp.inputToken, temp.outputToken, temp.amountOut) = _dispatchWithAmount(
                        command,
                        inputs[idx],
                        amountOut - batchSwap.accAmountIn
                    );
                } else {
                    uint256 spentAmountIn = (amountOut * singleHopWeights[j]) / batchSwap.weightSum;
                    batchSwap.accAmountIn += spentAmountIn;
                    (temp.inputToken, temp.outputToken, temp.amountOut) = _dispatchWithAmount(
                        command,
                        inputs[idx],
                        spentAmountIn
                    );
                }
                batchSwap.amountOut += temp.amountOut;

                if (j == 0) {
                    batchSwap.inputToken = temp.inputToken;
                    batchSwap.outputToken = temp.outputToken;
                    if (i == 0) {
                        inputToken = temp.inputToken;
                        prevToken = temp.outputToken;
                        if (weights.length == 1) {
                            outputToken = temp.outputToken;
                        }
                    } else if (i == weights.length - 1) {
                        outputToken = temp.outputToken;
                    } else {
                        if (batchSwap.inputToken != prevToken) {
                            revert InvalidBatchPath();
                        }
                        prevToken = temp.outputToken;
                    }
                } else {
                    if (batchSwap.inputToken != temp.inputToken || batchSwap.outputToken != temp.outputToken) {
                        revert InvalidBatchPath();
                    }
                }

                idx += 1;
            }

            amountOut = batchSwap.amountOut;
        }
    }

    function _parseDelegatecall(bool success, bytes memory outputs) private returns (uint256 amountOut) {
        if (!success) {
            if (outputs.length < 68) revert();
            assembly {
                outputs := add(outputs, 0x04)
            }
            revert(abi.decode(outputs, (string)));
        } else {
            amountOut = abi.decode(outputs, (uint256));
        }
    }

    function _dispatchWithAmount(
        uint256 command,
        bytes memory inputs,
        uint256 amountIn
    )
        internal
        returns (
            address inputToken,
            address outputToken,
            uint256 amountOut
        )
    {
        if (command < 0x20) {
            if (command < 0x10) {
                // 0x00 <= command < 0x08
                if (command < 0x08) {
                    if (command == Commands.UNI_V3_SWAP_EXACT_IN) {
                        (
                            address recipient,
                            uint256 amount,
                            // uint256 amountOutMin,
                            bytes memory path,
                            bool payerIsUser
                        ) = abi.decode(inputs, (address, uint256, bytes, bool));
                        // address payer = payerIsUser ? msg.sender : address(this);
                        amountOut = uniswapV3SwapExactInput(
                            recipient.map(),
                            amountIn == 0 ? amount : amountIn,
                            path,
                            payerIsUser ? msg.sender : address(this)
                        );
                        // (bool success, bytes memory outputs) = UNI_V3_SWAP_ROUTER.delegatecall(abi.encodeWithSelector(
                        //     0x23e05f13, // UniV3SwapRouter.uniswapV3SwapExactInput.selector
                        //     recipient.map(),
                        //     amountIn == 0 ? amount : amountIn,
                        //     amountOutMin,
                        //     path,
                        //     payerIsUser ? msg.sender : address(this)
                        // ));

                        // if(!success){
                        //     if (outputs.length < 68) revert();
                        //     assembly {
                        //         outputs := add(outputs, 0x04)
                        //     }
                        //     revert(abi.decode(outputs, (string)));
                        // }else{
                        //     amountOut =abi.decode (outputs, (uint256));
                        // }

                        inputToken = path.decodeFirstToken();
                        while (true) {
                            bool hasMultiplePools = path.hasMultiplePools();
                            if (hasMultiplePools) {
                                path.skipToken();
                            } else {
                                outputToken = path.decodeFirstToken();
                                break;
                            }
                        }
                    } else if (command == Commands.PERMIT2_TRANSFER_FROM) {
                        (address token, address recipient, uint160 amount) = abi.decode(
                            inputs,
                            (address, address, uint160)
                        );
                        permit2TransferFrom(token, msg.sender, recipient, amount);
                    } else if (command == Commands.PERMIT2_PERMIT_BATCH) {
                        (IAllowanceTransfer.PermitBatch memory permitBatch, bytes memory data) = abi.decode(
                            inputs,
                            (IAllowanceTransfer.PermitBatch, bytes)
                        );
                        PERMIT2.permit(msg.sender, permitBatch, data);
                    } else if (command == Commands.SWEEP) {
                        (address token, address recipient, uint256 amountMin) = abi.decode(
                            inputs,
                            (address, address, uint256)
                        );
                        Payments.sweep(token, recipient.map(), amountMin);
                    } else if (command == Commands.TRANSFER) {
                        (address token, address recipient, uint256 value) = abi.decode(
                            inputs,
                            (address, address, uint256)
                        );
                        Payments.pay(token, recipient.map(), value);
                    } else if (command == Commands.PAY_PORTION) {
                        (address token, address recipient, uint256 bips) = abi.decode(
                            inputs,
                            (address, address, uint256)
                        );
                        Payments.payPortion(token, recipient.map(), bips);
                    } else {
                        // placeholder area for command 0x07
                        revert InvalidCommandType(command);
                    }
                    // 0x08 <= command < 0x10
                } else {
                    if (command == Commands.UNI_V2_SWAP_EXACT_IN) {
                        (
                            address recipient,
                            uint256 amount,
                            // uint256 amountOutMin,
                            address[] memory path,
                            bool payerIsUser
                        ) = abi.decode(inputs, (address, uint256, address[], bool));
                        // address payer = payerIsUser ? msg.sender : address(this);
                        // amountOut = uniV2SwapExactInput(
                        //     recipient.map(),
                        //     amountIn == 0 ? amount : amountIn,
                        // //     amountOutMin,
                        //     path,
                        //     payerIsUser ? msg.sender : address(this)
                        // );
                        (bool success, bytes memory outputs) = UNI_V2_SWAP_ROUTER.delegatecall(
                            abi.encodeWithSelector(
                                0xfa5cbdda, // UniV2RouterSwapAdatper.uniV2RouterSwapExactInput.selector
                                recipient.map(),
                                amountIn == 0 ? amount : amountIn,
                                // amountOutMin,
                                path,
                                payerIsUser ? msg.sender : address(this)
                            )
                        );
                        amountOut = _parseDelegatecall(success, outputs);
                        inputToken = path[0];
                        outputToken = path[path.length - 1];
                    } else if (command == Commands.UNI_V2_ROUTER_SWAP_EXACT_IN) {
                        (
                            address recipient,
                            uint256 amount,
                            // uint256 amountOutMin,
                            address router,
                            address[] memory path,
                            bool payerIsUser
                        ) = abi.decode(inputs, (address, uint256, address, address[], bool));
                        // address payer = payerIsUser ? msg.sender : address(this);
                        // amountOut = uniV2RouterSwapExactInput(
                        //     recipient.map(),
                        //     amountIn == 0 ? amount : amountIn,
                        // //     amountOutMin,
                        //     router,
                        //     path,
                        //     payerIsUser ? msg.sender : address(this)
                        // );
                        (bool success, bytes memory outputs) = UNI_V2_ROUTER_SWAP_ADAPTER.delegatecall(
                            abi.encodeWithSelector(
                                0x2f5ff7e3, // UniV2RouterSwapAdatper.uniV2RouterSwapExactInput.selector
                                recipient.map(),
                                amountIn == 0 ? amount : amountIn,
                                // amountOutMin,
                                router,
                                path,
                                payerIsUser ? msg.sender : address(this)
                            )
                        );
                        amountOut = _parseDelegatecall(success, outputs);

                        inputToken = path[0];
                        outputToken = path[path.length - 1];
                    } else if (command == Commands.PERMIT2_PERMIT) {
                        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory data) = abi.decode(
                            inputs,
                            (IAllowanceTransfer.PermitSingle, bytes)
                        );
                        PERMIT2.permit(msg.sender, permitSingle, data);
                    } else if (command == Commands.WRAP_ETH) {
                        (address recipient, ) = abi.decode(inputs, (address, uint256));
                        amountOut = Payments.wrapETH(recipient.map(), amountIn);
                        inputToken = Constants.ETH;
                        outputToken = address(WETH9);
                    } else if (command == Commands.UNWRAP_WETH) {
                        (address recipient, ) = abi.decode(inputs, (address, uint256));
                        amountOut = Payments.unwrapWETH9(recipient.map(), amountIn);
                        inputToken = address(WETH9);
                        outputToken = Constants.ETH;
                    } else if (command == Commands.PERMIT2_TRANSFER_FROM_BATCH) {
                        IAllowanceTransfer.AllowanceTransferDetails[] memory batchDetails = abi.decode(
                            inputs,
                            (IAllowanceTransfer.AllowanceTransferDetails[])
                        );
                        permit2TransferFrom(batchDetails);
                    } else {
                        // placeholder area for commands 0x0f
                        revert InvalidCommandType(command);
                    }
                }
                // 0x10 <= command
            } else {
                // 0x10 <= command < 0x18
                if (command < 0x18) {
                    if (command == Commands.AAVE_LENDING_POOLS) {
                        (address lendingPool, uint8 functionVersion, bytes memory executeParams, bool payerIsUser) = abi
                            .decode(inputs, (address, uint8, bytes, bool));
                        // address payer = payerIsUser ? msg.sender : address(this);
                        // (inputToken, outputToken, amountOut) = aaveExecute(
                        //     lendingPool,
                        //     functionVersion,
                        //     executeParams,
                        //     payerIsUser ? msg.sender : address(this)
                        // );
                        (bool success, bytes memory outputs) = AAVE_ADAPTER.delegatecall(
                            abi.encodeWithSelector(
                                0x06c5fa68, // AaveAdapter.aaveExecute.selector
                                lendingPool,
                                functionVersion,
                                executeParams,
                                payerIsUser ? msg.sender : address(this)
                            )
                        );
                        if (!success) {
                            if (outputs.length < 68) revert();
                            assembly {
                                outputs := add(outputs, 0x04)
                            }
                            revert(abi.decode(outputs, (string)));
                        } else {
                            (inputToken, outputToken, amountOut) = abi.decode(outputs, (address, address, uint256));
                        }
                        // } else if (command == Commands.COMPOUND_LENDING_POOLS) {
                        //     revert InvalidCommandType(command);
                        // } else if (command == Commands.YEARN_LENDING_POOLS) {
                        //     revert InvalidCommandType(command);
                    } else if (command == Commands.CURVE_SWAP_EXACT_IN) {
                        (
                            uint256 amount,
                            // uint256 amountOutMin,
                            uint256[3][] memory swapParams,
                            address recipient,
                            address[] memory path,
                            bool payerIsUser
                        ) = abi.decode(inputs, (uint256, uint256[3][], address, address[], bool));
                        // address payer = payerIsUser ? msg.sender : address(this);
                        // amountOut = curveSwapExactInput(
                        //     amountIn == 0 ? amount : amountIn,
                        // //     amountOutMin,
                        //     swapParams,
                        //     recipient.map(),
                        //     payerIsUser ? msg.sender : address(this),
                        //     path
                        // );
                        inputToken = path[0];
                        outputToken = path[path.length - 1];
                        address payer = payerIsUser ? msg.sender : address(this);

                        if (inputToken == Constants.ETH) {
                            (bool success, bytes memory outputs) = CURVE_SWAP_ROUTER.call{value: amount}(
                                abi.encodeWithSelector(
                                    0x012f4e8a, // CurveSwapRouter.curveSwapExactInput.selector
                                    amountIn == 0 ? amount : amountIn,
                                    // amountOutMin,
                                    swapParams,
                                    recipient.map(),
                                    payer,
                                    path
                                )
                            );
                            amountOut = _parseDelegatecall(success, outputs);
                        } else {
                            (bool success, bytes memory outputs) = CURVE_SWAP_ROUTER.delegatecall(
                                abi.encodeWithSelector(
                                    0x012f4e8a, // CurveSwapRouter.curveSwapExactInput.selector
                                    amountIn == 0 ? amount : amountIn,
                                    // amountOutMin,
                                    swapParams,
                                    recipient.map(),
                                    payer,
                                    path
                                )
                            );
                            amountOut = _parseDelegatecall(success, outputs);
                        }
                    } else if (command == Commands.DODOV2_SWAP_EXACT_IN) {
                        (
                            uint256 amount,
                            // uint256 amountOutMinimum,
                            uint256 directions,
                            address tokenIn,
                            address tokenOut,
                            address[] memory dodoPairs,
                            address recipient,
                            bool payerIsUser,
                            uint8[] memory versions
                        ) = abi.decode(inputs, (uint256, uint256, address, address, address[], address, bool, uint8[]));
                        // address payer = payerIsUser ? msg.sender : address(this);
                        // amountOut = dodoSwapExactInput(
                        //     amountIn == 0 ? amount : amountIn,
                        // //     amountOutMinimum,
                        //     directions,
                        //     tokenIn,
                        //     tokenOut,
                        //     dodoPairs,
                        //     recipient.map(),
                        //     payerIsUser ? msg.sender : address(this),
                        //     versions
                        // );
                        (bool success, bytes memory outputs) = DODO_SWAP_ROUTER.delegatecall(
                            abi.encodeWithSelector(
                                0x4298d91d, // DodoSwapRouter.dodoSwapExactInput.selector
                                amountIn == 0 ? amount : amountIn,
                                // amountOutMinimum,
                                directions,
                                tokenIn,
                                tokenOut,
                                dodoPairs,
                                recipient.map(),
                                payerIsUser ? msg.sender : address(this),
                                versions
                            )
                        );
                        amountOut = _parseDelegatecall(success, outputs);
                        inputToken = tokenIn;
                        outputToken = tokenOut;
                    } else if (command == Commands.BALV2_SWAP_EXACT_IN) {
                        (
                            uint256 amount,
                            // uint256 amountOutMin,
                            bytes32[] memory path,
                            address recipient,
                            bool payerIsUser
                        ) = abi.decode(inputs, (uint256, bytes32[], address, bool));
                        // address payer = payerIsUser ? msg.sender : address(this);
                        // amountOut = balancerSwapExactInput(
                        //     amountIn == 0 ? amount : amountIn,
                        // //     amountOutMin,
                        //     path,
                        //     recipient.map(),
                        //     payerIsUser ? msg.sender : address(this)
                        // );

                        inputToken = address(uint160(uint256(path[0])));
                        outputToken = address(uint160(uint256(path[path.length - 1])));
                        address payer = payerIsUser ? msg.sender : address(this);

                        (bool success, bytes memory outputs) = BALANCER_SWAP_ROUTER.delegatecall(
                            abi.encodeWithSelector(
                                0xbc0aec36, // BalancerSwapRouter.balancerSwapExactInput.selector
                                amountIn == 0 ? amount : amountIn,
                                // amountOutMin,
                                path,
                                recipient.map(),
                                payer
                            )
                        );
                        amountOut = _parseDelegatecall(success, outputs);

                        // } else if (command == Commands.KYBERV2_SWAP_EXACT_IN) {
                        //     revert InvalidCommandType(command);
                        // } else if (command == Commands.RFQ_SWAP_EXACT_IN) {
                        //     revert InvalidCommandType(command);
                    }
                    // 0x18 <= command < 0x1f
                } else {
                    if (command == Commands.SADDLE_SWAP_EXACT_IN) {
                        (
                            uint256 amount,
                            // uint256 amountOutMin,
                            uint256[3][] memory swapParams,
                            address recipient,
                            address[] memory path,
                            bool payerIsUser
                        ) = abi.decode(inputs, (uint256, uint256[3][], address, address[], bool));
                        // address payer = payerIsUser ? msg.sender : address(this);
                        // amountOut = saddleSwapExactInput(
                        //     amountIn == 0 ? amount : amountIn,
                        // //     amountOutMin,
                        //     swapParams,
                        //     recipient.map(),
                        //     payerIsUser ? msg.sender : address(this),
                        //     path
                        // );
                        (bool success, bytes memory outputs) = SADDLE_SWAP_ROUTER.delegatecall(
                            abi.encodeWithSelector(
                                0x6fa738c3, // SaddleSwapRouter.saddleSwapExactInput.selector
                                amountIn == 0 ? amount : amountIn,
                                // amountOutMin,
                                swapParams,
                                recipient.map(),
                                payerIsUser ? msg.sender : address(this),
                                path
                            )
                        );
                        if (!success) {
                            if (outputs.length < 68) revert();
                            assembly {
                                outputs := add(outputs, 0x04)
                            }
                            revert(abi.decode(outputs, (string)));
                        } else {
                            amountOut = abi.decode(outputs, (uint256));
                        }

                        inputToken = path[0];
                        outputToken = path[path.length - 1];
                        // } else if (command == Commands.WOO_EXACT_IN) {
                        //     revert InvalidCommandType(command);
                        // } else if (command == Commands.SYNTHETIX_EXACT_IN) {
                        //     revert InvalidCommandType(command);
                        // } else if (command == Commands.DMM_EXACT_IN) {
                        //     revert InvalidCommandType(command);
                    } else {
                        // placeholder area for commands 0x1e-0x1f
                        revert InvalidCommandType(command);
                    }
                }
            }
        } else {
            revert InvalidCommandType(command);
        }
    }

    /// @notice Performs a call to purchase an ERC721, then transfers the ERC721 to a specified recipient
    /// @param inputs The inputs for the protocol and ERC721 transfer, encoded
    /// @param protocol The protocol to pass the calldata to
    /// @return success True on success of the command, false on failure
    /// @return output The outputs or error messages, if any, from the command
    function callAndTransfer721(bytes memory inputs, address protocol)
        internal
        returns (bool success, bytes memory output)
    {
        (uint256 value, bytes memory data, address recipient, address token, uint256 id) = abi.decode(
            inputs,
            (uint256, bytes, address, address, uint256)
        );
        (success, output) = protocol.call{value: value}(data);
        if (success) ERC721(token).safeTransferFrom(address(this), recipient.map(), id);
    }

    /// @notice Performs a call to purchase an ERC1155, then transfers the ERC1155 to a specified recipient
    /// @param inputs The inputs for the protocol and ERC1155 transfer, encoded
    /// @param protocol The protocol to pass the calldata to
    /// @return success True on success of the command, false on failure
    /// @return output The outputs or error messages, if any, from the command
    function callAndTransfer1155(bytes memory inputs, address protocol)
        internal
        returns (bool success, bytes memory output)
    {
        (uint256 value, bytes memory data, address recipient, address token, uint256 id, uint256 amount) = abi.decode(
            inputs,
            (uint256, bytes, address, address, uint256, uint256)
        );
        (success, output) = protocol.call{value: value}(data);
        if (success) ERC1155(token).safeTransferFrom(address(this), recipient.map(), id, amount, new bytes(0));
    }
}
