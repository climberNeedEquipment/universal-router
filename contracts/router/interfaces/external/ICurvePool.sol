// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface AddressProvider {
    function get_registry() external view returns (address);

    function get_address(uint256 _id) external view returns (address);

    function max_id() external view returns (uint256);
}

interface CurveCryptoRegsitry {
    function get_coin_indices(
        address pool,
        address from,
        address to
    ) external view returns (uint256, uint256);
}

interface CurveRegistry {
    function address_provider() external view returns (address);

    function get_A(address _pool) external view returns (uint256);

    // Pool fee as uint256 with 1e10 precision
    // Admin fee as 1e10 percentage of pool fee
    // Mid fee (if cryptopool)
    // Out fee (if cryptopool)
    function get_fees(address _pool) external view returns (uint256[2] memory);

    function pool_list(uint256 idx) external view returns (address);

    function pool_count() external view returns (uint256);

    function get_n_coins(address _pool) external view returns (uint256[2] memory);

    function get_coins(address _pool) external view returns (address[8] memory);

    function get_underlying_coins(address _pool) external view returns (address[8] memory);

    function get_decimals(address _pool) external view returns (uint256[8] memory);

    function get_underlying_decimals(address _pool) external view returns (uint256[8] memory);

    function get_balances(address _pool) external view returns (uint256[8] memory);

    function get_underlying_balances(address _pool) external view returns (uint256[8] memory);

    function get_rates(address _pool) external view returns (uint256[8] memory);

    function get_lp_token(address _pool) external view returns (address);

    function is_meta(address _pool) external view returns (bool);

    function get_pool_name(address _pool) external view returns (string memory);

    function find_pool_for_coins(
        address _srcToken,
        address _dstToken,
        uint256 _index
    ) external view returns (address);

    function get_coin_indices(
        address _pool,
        address _srcToken,
        address _dstToken
    )
        external
        view
        returns (
            int128,
            int128,
            bool
        );
}

interface CurvePool {
    // solium-disable-next-line mixedcase
    function get_dy_underlying(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256 dy);

    // solium-disable-next-line mixedcase
    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256 dy);

    // solium-disable-next-line mixedcase
    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 minDy
    ) external payable;

    // solium-disable-next-line mixedcase
    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 minDy
    ) external payable;

    function coins(uint256 i) external view returns (address out);

    function underlying_coins(uint256 i) external view returns (address out);

    function remove_liquidity(
        uint256 _amount,
        uint256[2] memory _min_amounts,
        bool _use_underlying
    ) external;

    function remove_liquidity_one_coin(
        uint256 _token_amount,
        int128 i,
        uint256 _min_amount
    ) external;

    function add_liquidity(uint256[3] memory _amounts, uint256 _min_mint_amount) external;

    function lp_token() external view returns (address);

    function balances(uint256 arg0) external view returns (uint256 balance);

    function A() external view returns (uint256);

    function token() external view returns (address);
}

interface CryptoPool {
    function token() external view returns(address);

    // solium-disable-next-line mixedcase
    function get_dy_underlying(
        uint256 i,
        uint256 j,
        uint256 dx
    ) external view returns (uint256 dy);

    // solium-disable-next-line mixedcase
    function get_dy(
        uint256 i,
        uint256 j,
        uint256 dx
    ) external view returns (uint256 dy);

    // solium-disable-next-line mixedcase
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 minDy
    ) external payable returns (uint256);

    // solium-disable-next-line mixedcase
    function exchange_underlying(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 minDy
    ) external payable returns (uint256);

    function coins(uint256 i) external view returns (address out);

    function underlying_coins(uint256 i) external view returns (address out);

    function calc_withdraw_one_coin(uint256 _token_amount, uint256 i) external view returns (uint256);

    function calc_token_amount(uint256[2] memory _amounts) external view returns (uint256); // crypto factory registry

    function calc_token_amount(uint256[3] memory _amounts, bool deposit) external view returns (uint256); // crypto registry

    function add_liquidity(
        uint256[2] memory amounts,
        uint256 min_mint_amount,
        bool use_eth
    ) external payable;

    function remove_liquidity_one_coin(
        uint256 token_amount,
        uint256 i,
        uint256 min_amount,
        bool use_eth
    ) external;

    function remove_liquidity_one_coin(
        uint256 token_amount,
        uint256 i,
        uint256 min_amount
    ) external;

    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external payable;
}

interface CryptoPoolETH {
    // solium-disable-next-line mixedcase
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 minDy,
        bool use_eth
    ) external payable returns (uint256);
}

interface LendingBasePoolMetaZap {
    // solium-disable-next-line mixedcase
    function exchange(
        address pool,
        int128 i,
        int128 j,
        uint256 dx,
        uint256 minDy
    ) external returns (uint256);
}

interface CryptoMetaZap {
    function exchange(
        address pool,
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 minDy,
        bool use_eth
    ) external payable;

    function get_dy(
        address pool,
        uint256 i,
        uint256 j,
        uint256 dx
    ) external view returns (uint256);
}

interface BasePool2Coins {
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external;

    function calc_token_amount(uint256[2] memory amounts, bool is_deposit) external view returns (uint256);

    function remove_liquidity_one_coin(
        uint256 token_amount,
        int128 i,
        uint256 min_amount
    ) external;

    function calc_withdraw_one_coin(uint256 token_amount, int128 i) external view returns (uint256);
}

interface BasePool3Coins {
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external;

    function calc_token_amount(uint256[3] memory amounts, bool is_deposit) external view returns (uint256);

    function remove_liquidity_one_coin(
        uint256 token_amount,
        int128 i,
        uint256 min_amount
    ) external;

    function calc_withdraw_one_coin(uint256 token_amount, int128 i) external view returns (uint256);
}

interface LendingBasePool3Coins {
    function add_liquidity(
        uint256[3] memory amounts,
        uint256 min_mint_amount,
        bool use_underlying
    ) external;

    function calc_token_amount(uint256[3] memory amounts, bool is_deposit) external view returns (uint256);

    function remove_liquidity_one_coin(
        uint256 token_amount,
        int128 i,
        uint256 min_amount,
        bool use_underlying
    ) external;

    function calc_withdraw_one_coin(uint256 token_amount, int128 i) external view returns (uint256);
}

interface CryptoBasePool3Coins {
    function add_liquidity(
        uint256[3] memory amounts,
        uint256 min_mint_amount,
        bool use_underlying
    ) external;

    function calc_token_amount(uint256[3] memory amounts, bool is_deposit) external view returns (uint256);

    function remove_liquidity_one_coin(
        uint256 token_amount,
        uint256 i,
        uint256 min_amount
    ) external;

    function calc_withdraw_one_coin(uint256 token_amount, uint256 i) external view returns (uint256);
}

interface BasePool4Coins {
    function add_liquidity(uint256[4] memory amounts, uint256 min_mint_amount) external;

    function calc_token_amount(uint256[4] memory amounts, bool is_deposit) external view returns (uint256);

    function remove_liquidity_one_coin(
        uint256 token_amount,
        int128 i,
        uint256 min_amount
    ) external;

    function calc_withdraw_one_coin(uint256 token_amount, int128 i) external view returns (uint256);
}

interface BasePool5Coins {
    function add_liquidity(uint256[5] memory amounts, uint256 min_mint_amount) external;

    function calc_token_amount(uint256[5] memory amounts, bool is_deposit) external view returns (uint256);

    function remove_liquidity_one_coin(
        uint256 token_amount,
        int128 i,
        uint256 min_amount
    ) external;

    function calc_withdraw_one_coin(uint256 token_amount, int128 i) external view returns (uint256);
}
