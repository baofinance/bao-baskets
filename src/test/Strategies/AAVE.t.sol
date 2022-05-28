pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "./LendingLogic.t.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";

contract AAVEStrategyTest is Test, LendingLogicTest {

    ERC20 public RAI;
    ERC20 public aRAI;

    constructor() LendingLogicTest() {
        lendingLogic = testSuite.lendingLogicAave();
    }

    function setUp() public {
        RAI = ERC20(testSuite.constants().RAI());
        aRAI = ERC20(testSuite.constants().aRAI());

        // Get RAI from top holder
        testSuite.cheats().startPrank(testSuite.constants().tokenHolders(address(RAI)));

        // Send RAI to this contract
        RAI.transfer(address(this), 1e20);

        testSuite.cheats().stopPrank();
    }

    function testLendUnlend() public {
        uint256 raiBalance = RAI.balanceOf(address(this));

        lend(
            address(RAI),
            raiBalance,
            address(this)
        );

        uint256 actual = aRAI.balanceOf(address(this));
        uint256 expected = raiBalance * lendingLogic.exchangeRate(address(aRAI)) / 1 ether;
        assertEq(actual, expected);

        unlend(
            address(aRAI),
            actual,
            address(this)
        );

        actual = RAI.balanceOf(address(this));
        expected = raiBalance;
        assertEq(actual, expected);
    }
}