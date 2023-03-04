// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IAllowanceTransfer} from 'permit2/src/interfaces/IAllowanceTransfer.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {IWETH9} from '../interfaces/external/IWETH9.sol';

// import '@openzeppelin/contracts/utils/StorageSlot.sol';
struct RouterParameters {
    address permit2;
    address weth9;
    address seaport;
    address nftxZap;
    address x2y2;
    address foundation;
    address sudoswap;
    address nft20Zap;
    address cryptopunks;
    address looksRare;
    address routerRewardsDistributor;
    address looksRareRewardsDistributor;
    address looksRareToken;
    address v2Viewer;
    address aaveViewer;
    address v3Factory;
    address balancerVault;
    address dodoV1SellHelper;
    bytes32 pairInitCodeHash;
    bytes32 poolInitCodeHash;
    // each routers for delegatecall
    // address uniV2SwapRouter;
    // address uniV2RouterSwapAdapter;
    // address uniV3SwapRouter;
    // address aaveAdapter;
    // address balancerSwapRouter;
    // address curveSwapRouter;
    // address saddleSwapRouter;
    // address dodoSwapRouter;
}

/// @title Router Immutable Storage contract
/// @notice Used along with the `RouterParameters` struct for ease of cross-chain deployment
contract RouterImmutables {
    // using StorageSlot for bytes32;
    /// @dev WETH9 address
    IWETH9 internal immutable WETH9;

    /// @dev Permit2 address
    IAllowanceTransfer internal immutable PERMIT2;

    // /// @dev Seaport address
    // address internal immutable SEAPORT;

    // /// @dev The address of NFTX zap contract for interfacing with vaults
    // address internal immutable NFTX_ZAP;

    // /// @dev The address of X2Y2
    // address internal immutable X2Y2;

    // // @dev The address of Foundation
    // address internal immutable FOUNDATION;

    // // @dev The address of Sudoswap's router
    // address internal immutable SUDOSWAP;

    // // @dev the address of NFT20's zap contract
    // address internal immutable NFT20_ZAP;

    // // @dev the address of Larva Lab's cryptopunks marketplace
    // address internal immutable CRYPTOPUNKS;

    // /// @dev The address of LooksRare
    // address internal immutable LOOKS_RARE;

    // /// @dev The address of LooksRare token
    // ERC20 internal immutable LOOKS_RARE_TOKEN;

    // /// @dev The address of LooksRare rewards distributor
    // address internal immutable LOOKS_RARE_REWARDS_DISTRIBUTOR;

    /// @dev The address of router rewards distributor
    address internal immutable ROUTER_REWARDS_DISTRIBUTOR;

    /// @dev The address of UniswapV2Viewer
    address internal immutable UNISWAP_V2_VIEWER;

    /// @dev The address of aaveViewer
    address internal immutable AAVE_VIEWER;

    // /// @dev The address of UniswapV2Pair initcodehash
    // bytes32 internal immutable UNISWAP_V2_PAIR_INIT_CODE_HASH;

    /// @dev The address of UniswapV3Factory
    address internal immutable UNISWAP_V3_FACTORY;

    /// @dev The address of UniswapV3Pool initcodehash
    bytes32 internal immutable UNISWAP_V3_POOL_INIT_CODE_HASH;

    /// @dev The address of DodoV1SellHelper
    address internal immutable DODO_V1_SELL_HELPER;

    /// @dev The address of BalancerVault
    address internal immutable BALANCER_VAULT;

    // address internal immutable UNI_V2_SWAP_ROUTER;
    // address internal immutable UNI_V2_ROUTER_SWAP_ADAPTER;
    // address internal immutable UNI_V3_SWAP_ROUTER;
    // address internal immutable AAVE_ADAPTER;
    // address internal immutable BALANCER_SWAP_ROUTER;
    // address internal immutable CURVE_SWAP_ROUTER;
    // address internal immutable SADDLE_SWAP_ROUTER;
    // address internal immutable DODO_SWAP_ROUTER;

    constructor(RouterParameters memory params) {
        PERMIT2 = IAllowanceTransfer(params.permit2);
        WETH9 = IWETH9(params.weth9);
        // SEAPORT = params.seaport;
        // NFTX_ZAP = params.nftxZap;
        // X2Y2 = params.x2y2;
        // FOUNDATION = params.foundation;
        // SUDOSWAP = params.sudoswap;
        // NFT20_ZAP = params.nft20Zap;
        // CRYPTOPUNKS = params.cryptopunks;
        // LOOKS_RARE = params.looksRare;
        // LOOKS_RARE_TOKEN = ERC20(params.looksRareToken);
        // LOOKS_RARE_REWARDS_DISTRIBUTOR = params.looksRareRewardsDistributor;
        ROUTER_REWARDS_DISTRIBUTOR = params.routerRewardsDistributor;
        UNISWAP_V2_VIEWER = params.v2Viewer;
        AAVE_VIEWER = params.aaveViewer;
        // UNISWAP_V2_PAIR_INIT_CODE_HASH = params.pairInitCodeHash;
        UNISWAP_V3_FACTORY = params.v3Factory;
        UNISWAP_V3_POOL_INIT_CODE_HASH = params.poolInitCodeHash;
        DODO_V1_SELL_HELPER = params.dodoV1SellHelper;
        BALANCER_VAULT = params.balancerVault;
        // each router for delegatecall
        // UNI_V2_SWAP_ROUTER = params.uniV2SwapRouter;
        // UNI_V2_ROUTER_SWAP_ADAPTER = params.uniV2RouterSwapAdapter;
        // UNI_V3_SWAP_ROUTER = params.uniV3SwapRouter;
        // AAVE_ADAPTER = params.aaveAdapter;
        // BALANCER_SWAP_ROUTER = params.balancerSwapRouter;
        // CURVE_SWAP_ROUTER = params.curveSwapRouter;
        // SADDLE_SWAP_ROUTER = params.saddleSwapRouter;
        // DODO_SWAP_ROUTER = params.dodoSwapRouter;
    }
}
