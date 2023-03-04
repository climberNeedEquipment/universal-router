// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IAllowanceTransfer} from 'permit2/src/interfaces/IAllowanceTransfer.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {IWETH9} from '../interfaces/external/IWETH9.sol';

import '@openzeppelin/contracts/utils/StorageSlot.sol';
struct ModuleParameters {
    address uniV2SwapRouter;
    address uniV2RouterSwapAdapter;
    address uniV3SwapRouter;
    address aaveAdapter;
    address balancerSwapRouter;
    address curveSwapRouter;
    address saddleSwapRouter;
    address dodoSwapRouter;
}

/// @title Module Immutable Storage contract
/// @notice Used along with the `ModuleParameters` struct for ease of cross-chain deployment
contract ModuleImmutables {
    using StorageSlot for bytes32;

    /// @dev The deployed address of UniV2SwapRouter
    address internal immutable UNI_V2_SWAP_ROUTER;

    /// @dev The deployed address of UniV2RouterSwapAdapter
    address internal immutable UNI_V2_ROUTER_SWAP_ADAPTER;

    /// @dev The deployed address of UniV3SwapRouter
    address internal immutable UNI_V3_SWAP_ROUTER;

    /// @dev The deployed address of AaveAdapter
    address internal immutable AAVE_ADAPTER;

    /// @dev The deployed address of BalancerSwapRouter
    address internal immutable BALANCER_SWAP_ROUTER;

    /// @dev The deployed address of CurveSwapRouter
    address internal immutable CURVE_SWAP_ROUTER;

    /// @dev The deployed address of SaddleSwapRouter
    address internal immutable SADDLE_SWAP_ROUTER;

    /// @dev The deployed address of DodoSwapRouter
    address internal immutable DODO_SWAP_ROUTER;

    constructor(ModuleParameters memory params) {
        UNI_V2_SWAP_ROUTER = params.uniV2SwapRouter;
        UNI_V2_ROUTER_SWAP_ADAPTER = params.uniV2RouterSwapAdapter;
        UNI_V3_SWAP_ROUTER = params.uniV3SwapRouter;
        AAVE_ADAPTER = params.aaveAdapter;
        BALANCER_SWAP_ROUTER = params.balancerSwapRouter;
        CURVE_SWAP_ROUTER = params.curveSwapRouter;
        SADDLE_SWAP_ROUTER = params.saddleSwapRouter;
        DODO_SWAP_ROUTER = params.dodoSwapRouter;
    }
}
