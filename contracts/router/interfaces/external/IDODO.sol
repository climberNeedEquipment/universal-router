// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface IDODOSellHelper {
    function querySellQuoteToken(address pair, uint256 amountIn) external view returns (uint256);
}

interface IDODOStorage {
    function _BASE_TOKEN_() external view returns (address);

    function _QUOTE_TOKEN_() external view returns (address);

    function getDODOPool(address baseToken, address quoteToken) external view returns (address[] memory);
}

interface IDODOV2 is IDODOStorage {
    function querySellBase(address trader, uint256 payBaseAmount)
        external
        view
        returns (uint256 receiveQuoteAmount, uint256 mtFee);

    function querySellQuote(address trader, uint256 payQuoteAmount)
        external
        view
        returns (uint256 receiveBaseAmount, uint256 mtFee);

    function sellBase(address to) external returns (uint256 receiveQuoteAmount);

    function sellQuote(address to) external returns (uint256 receiveBaseAmount);

    function _MT_FEE_RATE_MODEL_() external view returns (address);

    function _LP_FEE_RATE_() external view returns (uint64);

    /// @notice get current state of PMM of DODO V2
    /// @return i is market price
    /// @return K is current K value
    /// @return B is current base token balance
    /// @return Q is current quote token balance
    /// @return B0 is target base token balance
    /// @return Q0 is target quote token balance
    /// @return R is current status of imbalance 0 is R=1, 1 is R>1, 2 is R<1
    function getPMMStateForCall()
        external
        view
        returns (
            uint256 i,
            uint256 K,
            uint256 B,
            uint256 Q,
            uint256 B0,
            uint256 Q0,
            uint256 R
        );

    function getMidPrice() external view returns (uint256 midPrice);

    function getUserFeeRate(address user) external view returns (uint256 lpFeeRate, uint256 mtFeeRate);
}

interface IDODOV1 is IDODOStorage {
    function querySellBaseToken(uint256 amount) external view returns (uint256 receiveQuote);

    function queryBuyBaseToken(uint256 amount) external view returns (uint256 payQuote);

    function _TRADE_ALLOWED_() external view returns (bool);

    // like lp token
    function _QUOTE_CAPITAL_TOKEN_() external view returns (address);

    // like lp token
    function _BASE_CAPITAL_TOKEN_() external view returns (address);

    function sellBaseToken(
        uint256 amount,
        uint256 minReceiveQuote,
        bytes calldata data
    ) external returns (uint256);

    function buyBaseToken(
        uint256 amount,
        uint256 maxPayQuote,
        bytes calldata data
    ) external returns (uint256);

    function getOraclePrice() external view returns (uint256);

    function _K_() external view returns (uint256);

    function _BASE_BALANCE_() external view returns (uint256);

    function _QUOTE_BALANCE_() external view returns (uint256);

    function getExpectedTarget() external view returns (uint256 baseTarget, uint256 quoteTarget);

    function _R_STATUS_() external view returns (uint256);

    function _LP_FEE_RATE_() external view returns (uint256);

    function _MT_FEE_RATE_() external view returns (uint256);
}

interface IDODOCaller {
    function querySellQuoteToken(address dodo, uint256 amount) external view returns (uint256);

    function querySellBaseToken(address dodo, uint256 amount) external view returns (uint256);

    function sellBase(address to) external returns (uint256);

    function sellQuote(address to) external returns (uint256);

    function sellBase(
        address to,
        address pool,
        bytes memory data
    ) external;

    function sellQuote(
        address to,
        address pool,
        bytes memory data
    ) external;
}
