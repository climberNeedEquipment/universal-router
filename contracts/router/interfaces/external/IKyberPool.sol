// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

/// @title The swap interface for a Kyber ProMM Pool
interface IProMMPool {
    /// @notice Swap token0 -> token1, or vice versa
    /// @dev This method's caller receives a callback in the form of ISwapCallback#swapCallback
    /// @dev swaps will execute up to limitSqrtP or swapQty is fully used
    /// @param recipient The address to receive the swap output
    /// @param swapQty The swap quantity, which implicitly configures the swap as exact input (>0), or exact output (<0)
    /// @param isToken0 Whether the swapQty is specified in token0 (true) or token1 (false)
    /// @param limitSqrtP the limit of sqrt price after swapping
    /// could be MAX_SQRT_RATIO-1 when swapping 1 -> 0 and MIN_SQRT_RATIO+1 when swapping 0 -> 1 for no limit swap
    /// @param data Any data to be passed through to the callback
    /// @return qty0 Exact token0 qty sent to recipient if < 0. Minimally received quantity if > 0.
    /// @return qty1 Exact token1 qty sent to recipient if < 0. Minimally received quantity if > 0.
    function swap(
        address recipient,
        int256 swapQty,
        bool isToken0,
        uint160 limitSqrtP,
        bytes calldata data
    ) external returns (int256 qty0, int256 qty1);
}
