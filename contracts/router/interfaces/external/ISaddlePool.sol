// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISaddlePool {
    function swapStorage()
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            address
        );

    function getToken(uint8 index) external view returns (address);

    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256);

    function swapUnderlying(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256);

    function addLiquidity(
        uint256[] memory amounts,
        uint256 minToMint,
        uint256 deadline
    ) external returns (uint256);

    function removeLiquidity(
        uint256 amount,
        uint256[] memory minAmounts,
        uint256 deadline
    ) external returns (uint256[] memory);

    function removeLiquidityOneToken(
        uint256 tokenAmount,
        uint8 tokenIndex,
        uint256 minAmount,
        uint256 deadline
    ) external returns (uint256);

    //function of saddle flash swap
    function calculateRemoveLiquidity(uint256 amount) external view returns (uint256[] memory);

    //function of saddle v1
    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minToMint,
        uint256 deadline,
        bytes32[] calldata merkleProof
    ) external returns (uint256);
}
