pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";
import "./LendingLogic.t.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";

contract CompoundStrategyTest is DSTest, LendingLogicTest {

    ERC20 public LINK;
    ERC20 public cLINK;

    constructor() LendingLogicTest() {
        lendingLogic = testSuite.lendingLogicCompound();
    }

    function setUp() public {
        LINK = ERC20(testSuite.LINK());
        cLINK = ERC20(testSuite.cLINK());

        // Impersonate the test suite
        testSuite.cheats().startPrank(address(testSuite));

        // Buy LINK
        uint256[] memory tokenAmounts = new uint256[](4);
        tokenAmounts[2] = 1e20; // 100 LINK
        testSuite.buyTokens(tokenAmounts);

        // Send LINK to this contract
        LINK.transfer(address(this), 1e20);

        testSuite.cheats().stopPrank();
    }

    function testLendUnlend() public {
        uint256 linkBalance = LINK.balanceOf(address(this));

        lend(
            address(LINK),
            linkBalance,
            address(this)
        );

        uint256 cLINKBalance = cLINK.balanceOf(address(this));
        uint256 actual = linkBalance;
        uint256 expected = cLINKBalance * lendingLogic.exchangeRate(address(cLINK)) / 10 ** LINK.decimals();
        assertRelApproxEq(expected, actual, 1e10); // 0.000001% delta threshold

        unlend(
            address(cLINK),
            cLINKBalance,
            address(this)
        );

        actual = LINK.balanceOf(address(this));
        expected = linkBalance;
        assertRelApproxEq(expected, actual, 1e10); // 0.000001% delta threshold
    }
}