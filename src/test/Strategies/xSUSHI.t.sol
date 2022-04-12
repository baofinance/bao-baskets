pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";
import "./LendingLogic.t.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";
import "../../Interfaces/IXSushi.sol";

contract SushiStakingStrategyTest is DSTest, LendingLogicTest {

    ERC20 public SUSHI;
    IXSushi public xSUSHI;

    constructor() LendingLogicTest() {
        lendingLogic = testSuite.stakingLogicSushi();
    }

    function setUp() public {
        SUSHI = ERC20(testSuite.SUSHI());
        xSUSHI = IXSushi(testSuite.xSUSHI());

        // Impersonate the test suite
        testSuite.cheats().startPrank(address(testSuite));

        // Buy SUSHI
        uint256[] memory tokenAmounts = new uint256[](4);
        tokenAmounts[3] = 1e22; // 10000 SUSHI
        testSuite.buyTokens(tokenAmounts);

        // Send SUSHI to this contract
        SUSHI.transfer(address(this), 1e22);

        testSuite.cheats().stopPrank();
    }

    function testLendUnlend() public {
        uint256 sushiBalance = SUSHI.balanceOf(address(this));

        emit log_named_uint("SUSHI balance", sushiBalance);

        lend(
            address(SUSHI),
            sushiBalance,
            address(this)
        );

        uint256 actual = xSUSHI.balanceOf(address(this));

        emit log_named_uint("xSUSHI balance", actual);
        emit log_named_uint("exchange rate", lendingLogic.exchangeRateView(address(xSUSHI)));

        uint256 expected = sushiBalance * 1e18 / lendingLogic.exchangeRate(address(xSUSHI));
        assertRelApproxEq(actual, expected, 1e12);

        unlend(
            address(xSUSHI),
            actual,
            address(this)
        );

        actual = SUSHI.balanceOf(address(this));
        expected = sushiBalance;
        assertRelApproxEq(actual, expected, 1e12);
    }
}