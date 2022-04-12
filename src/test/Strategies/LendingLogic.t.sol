pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../BasketsTestSuite.sol";
import "ds-test/test.sol";

contract LendingLogicTest is DSTest {

    ILendingLogic public lendingLogic;
    BasketsTestSuite public testSuite;

    constructor() {
        testSuite = new BasketsTestSuite();
    }

    function lend(
        address _underlying,
        uint256 _amount,
        address _tokenHolder
    ) public {
        (address[] memory _targets, bytes[] memory _data) = lendingLogic.lend(
            _underlying,
            _amount,
            _tokenHolder
        );

        for (uint8 i; i < _targets.length; i++) {
            (bool _success,) = _targets[i].call{value: 0}(_data[i]);
            require(_success, "Error");
        }
    }

    function unlend(
        address _wrapped,
        uint256 _amount,
        address _tokenHolder
    ) public {
        (address[] memory _targets, bytes[] memory _data) = lendingLogic.unlend(
            _wrapped,
            _amount,
            _tokenHolder
        );

        for (uint8 i; i < _targets.length; i++) {
            (bool _success,) = _targets[i].call{value: 0}(_data[i]);
            require(_success, "Error");
        }
    }

    // https://github.com/Rari-Capital/solmate/blob/main/src/test/utils/DSTestPlus.sol
    function assertRelApproxEq(
        uint256 a,
        uint256 b,
        uint256 maxPercentDelta
    ) internal virtual {
        uint256 delta = a > b ? a - b : b - a;
        uint256 abs = a > b ? a : b;

        uint256 percentDelta = (delta * 1e18) / abs;

        if (percentDelta > maxPercentDelta) {
            emit log("Error: a ~= b not satisfied [uint]");
            emit log_named_uint("    Expected", b);
            emit log_named_uint("      Actual", a);
            emit log_named_uint(" Max % Delta", maxPercentDelta);
            emit log_named_uint("     % Delta", percentDelta);
            fail();
        }
    }
}