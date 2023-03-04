// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import {IUniswapV2Pair} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import {IUniswapV2Factory} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

/// @title Uniswap v2 Helper Library
/// @notice Calculates the recipient address for a command
library UniswapV2Library {
    /// @notice Calculates the v2 address for a pair without making any external calls
    /// @param factory The address of the v2 factory
    /// @param tokenA One of the tokens in the pair
    /// @param tokenB The other token in the pair
    /// @return pair The resultant v2 pair address
    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (address pair) {
        pair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
    }

    /// @notice Calculates the v2 address for a pair and the pair's token0
    /// @param factory The address of the v2 factory
    /// @param tokenA One of the tokens in the pair
    /// @param tokenB The other token in the pair
    /// @return pair The resultant v2 pair address
    /// @return token0 The token considered token0 in this pair
    function pairAndToken0For(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (address pair, address token0) {
        address token1;
        (token0, token1) = sortTokens(tokenA, tokenB);
        pair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
    }

    /// @notice Calculates the v2 address for a pair and fetches the reserves for each token
    /// @param factory The address of the v2 factory
    /// @param tokenA One of the tokens in the pair
    /// @param tokenB The other token in the pair
    /// @return pair The resultant v2 pair address
    /// @return reserveA The reserves for tokenA
    /// @return reserveB The reserves for tokenB
    function pairAndReservesFor(
        address factory,
        address tokenA,
        address tokenB
    )
        private
        view
        returns (
            address pair,
            uint256 reserveA,
            uint256 reserveB
        )
    {
        address token0;
        (pair, token0) = pairAndToken0For(factory, tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /// @notice Sorts two tokens to return token0 and token1
    /// @param tokenA The first token to sort
    /// @param tokenB The other token to sort
    /// @return token0 The smaller token by address value
    /// @return token1 The larger token by address value
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}
