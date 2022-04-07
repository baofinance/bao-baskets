pragma solidity ^0.7.0;

import "ds-test/test.sol";
import "../../Recipes/Recipe.sol";
import "../BasketsTestSuite.sol";

contract OvenTest is DSTest {

    BasketsTestSuite public testSuite;
    Oven public oven;
    Recipe public recipe;

    function setUp() public {
        testSuite = new BasketsTestSuite();
        testSuite.cheats().startPrank(address(testSuite));
        oven = testSuite.oven();
        recipe = testSuite.recipe();
    }

    function testFailOvenCap() public {
        oven.setCap(1e18);
        oven.deposit{value : (1e18 + 1)}();
    }

    function testOvenDeposit() public {
        oven.setCap(1e18);
        oven.deposit{value : 1e18}();
        assertEq(oven.ethBalanceOf(address(testSuite)), 1e18);
    }

    function testOvenWithdrawETH() public {
        uint256 initialBalance = address(this).balance;

        oven.deposit{value : 1e18}();
        oven.withdrawETH(1e18, payable(address(testSuite)));
        assertEq(oven.ethBalanceOf(address(testSuite)), 0);
        assertEq(address(this).balance, initialBalance);
    }

    function testOvenBake() public {
        (uint256 mintPrice, uint16[] memory dexIndex) = recipe.getPricePie(testSuite.basket(), 1e18);

        oven.deposit{value : mintPrice}();

        IERC20 basket = IERC20(testSuite.basket());

        address[] memory receivers = new address[](1);
        receivers[0] = address(testSuite);
        uint initialBalance = basket.balanceOf(address(testSuite));

        oven.bake(receivers, 1e18, mintPrice);

        oven.withdrawOutput(address(testSuite));
        assertEq(basket.balanceOf(address(testSuite)), initialBalance + 1e18);
    }
}
