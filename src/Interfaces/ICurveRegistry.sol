pragma solidity ^0.7.0;

interface ICurveRegistry {
    function get_A(address _pool) external view returns (uint256);

    function get_n_coins(address _pool) external view returns (uint256[2] memory);

    function get_fees(address _pool) external view returns (uint256[2] memory);

    function get_coin_indices(
        address _pool,
        address _from,
        address _to
    ) external view returns (int128, int128, bool);

    function get_underlying_balances(address _pool) external view returns (uint256[8] memory);

    function get_underlying_decimals(address _pool) external view returns (uint256[8] memory);

    function get_balances(address _pool) external view returns (uint256[8] memory);

    function get_decimals(address _pool) external view returns (uint256[8] memory);

    function get_rates(address _pool) external view returns (uint256[8] memory);
}