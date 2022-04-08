pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";
import "./LendingLogic.t.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";

contract AAVEStrategyTest is DSTest, LendingLogicTest {

    ERC20 public DAI;
    ERC20 public aDAI;

    constructor() LendingLogicTest() {
        lendingLogic = testSuite.lendingLogicAave();
    }

    function setUp() public {
        DAI = ERC20(testSuite.DAI());
        aDAI = ERC20(testSuite.aDAI());

        // Impersonate the test suite
        testSuite.cheats().startPrank(address(testSuite));

        // Buy DAI
        uint256[] memory tokenAmounts = new uint256[](3);
        tokenAmounts[1] = 1e23; // 10000 DAI
        testSuite.buyTokens(tokenAmounts);

        // Send DAI to this contract
        DAI.transfer(address(this), 1e23);

        testSuite.cheats().stopPrank();
    }

    function testLendUnlend() public {
        uint256 daiBalance = DAI.balanceOf(address(this));

        lend(
            address(DAI),
            daiBalance,
            address(this)
        );

        uint256 actual = aDAI.balanceOf(address(this));
        uint256 expected = daiBalance * lendingLogic.exchangeRate(address(aDAI)) / 1 ether;
        assertEq(actual, expected);

        unlend(
            address(aDAI),
            actual,
            address(this)
        );

        actual = DAI.balanceOf(address(this));
        expected = daiBalance;
        assertEq(actual, expected);
    }
}