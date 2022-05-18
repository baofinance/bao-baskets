pragma solidity ^0.7.0;

interface ICurveCalculator {
    function get_dx(
        int128 n_coins,
        uint256[] memory balances,
        uint256 amp,
        uint256 fee,
        uint256[] memory rates,
        uint256[] memory precisions,
        bool underlying,
        int128 i,
        int128 j,
        uint256 dy
    ) external view returns (uint256);
}