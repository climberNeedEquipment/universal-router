// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface ISwapFlashLoan {
    //function of saddle flash swap
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
