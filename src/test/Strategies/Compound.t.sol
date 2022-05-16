pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "./LendingLogic.t.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";

contract CompoundStrategyTest is Test, LendingLogicTest {

    ERC20 public DAI;
    ERC20 public cDAI;

    constructor() LendingLogicTest() {
        lendingLogic = testSuite.lendingLogicCompound();
    }

    function setUp() public {
        DAI = ERC20(testSuite.constants().DAI());
        cDAI = ERC20(testSuite.constants().cDAI());

        // Impersonate the test suite
        testSuite.cheats().startPrank(address(testSuite));

        // Buy DAI
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1e20; // 100 LINK
        address[] memory tokens = new address[](1);
        tokens[0] = address(DAI);
        testSuite.buyTokens(tokenAmounts, tokens);

        // Send DAI to this contract
        DAI.transfer(address(this), 1e20);

        testSuite.cheats().stopPrank();
    }

    function testLendUnlend() public {
        uint256 linkBalance = DAI.balanceOf(address(this));

        lend(
            address(DAI),
            linkBalance,
            address(this)
        );

        uint256 cLINKBalance = cDAI.balanceOf(address(this));
        uint256 actual = linkBalance;
        uint256 expected = cLINKBalance * lendingLogic.exchangeRate(address(cDAI)) / 10 ** DAI.decimals();
        assertRelApproxEq(expected, actual, 1e10); // 0.000001% delta threshold

        unlend(
            address(cDAI),
            cLINKBalance,
            address(this)
        );

        actual = DAI.balanceOf(address(this));
        expected = linkBalance;
        assertRelApproxEq(expected, actual, 1e10); // 0.000001% delta threshold
    }
}