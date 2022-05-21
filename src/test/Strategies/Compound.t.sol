pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "./LendingLogic.t.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";

contract CompoundStrategyTest is Test, LendingLogicTest {

    ERC20 public UNI;
    ERC20 public cUNI;

    constructor() LendingLogicTest() {
        lendingLogic = testSuite.lendingLogicCompound();
    }

    function setUp() public {
        UNI = ERC20(testSuite.constants().UNI());
        cUNI = ERC20(testSuite.constants().cUNI());

        // Impersonate the test suite
        testSuite.cheats().startPrank(address(testSuite));

        // Buy UNI
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1e21; // 1000 UNI
        address[] memory tokens = new address[](1);
        tokens[0] = address(UNI);
        testSuite.buyTokens(tokenAmounts, tokens);

        // Send UNI to this contract
        UNI.transfer(address(this), 1e21);

        testSuite.cheats().stopPrank();
    }

    function testLendUnlend() public {
        uint256 uniBalance = UNI.balanceOf(address(this));

        lend(
            address(UNI),
            uniBalance,
            address(this)
        );

        uint256 actual = cUNI.balanceOf(address(this));
        uint256 expected = uniBalance * 1e18 / lendingLogic.exchangeRate(address(cUNI));

        assertEq(actual, expected);

        unlend(
            address(cUNI),
            actual,
            address(this)
        );

        expected = actual * lendingLogic.exchangeRate(address(cUNI)) / 1e18;
        actual = UNI.balanceOf(address(this));
        assertEq(actual, expected);
    }
}