pragma solidity ^0.7.0;

import "forge-std/Test.sol";
import "../../Recipes/Recipe.sol";
import "../BasketsTestSuite.sol";

contract SteamerTest is Test {

    BasketsTestSuite public testSuite;
    Steamer public steamer;
    Recipe public recipe;

    function setUp() public {
        testSuite = new BasketsTestSuite();
        startHoax(address(testSuite));
        steamer = testSuite.bSTBLSteamer();
        recipe = testSuite.recipe();
    }

    function testFailOvenCap() public {
        steamer.deposit{value : (1e18 + 1)}();
    }

    function testOvenDeposit() public {
        steamer.deposit{value : 1e18}();
        assertEq(steamer.ethBalanceOf(address(testSuite)), 1e18);
    }

    function testOvenWithdrawETH() public {
        uint256 initialBalance = address(this).balance;

        steamer.deposit{value : 1e18}();
        steamer.withdrawETH(1e18, payable(address(testSuite)));
        assertEq(steamer.ethBalanceOf(address(testSuite)), 0);
        assertEq(address(this).balance, initialBalance);
    }

    function testOvenBake() public {
        (uint256 mintPrice, uint16[] memory dexIndex) = recipe.getPricePie(testSuite.bSTBL(), 1e18);

        steamer.deposit{value : mintPrice}();

        IERC20 basket = IERC20(testSuite.bSTBL());

        address[] memory receivers = new address[](1);
        receivers[0] = address(testSuite);
        uint initialBalance = basket.balanceOf(address(testSuite));
        //Temporary for tests to compile
	uint mintAmount = 10 ether;
        steamer.steam(mintAmount);

        steamer.withdrawOutput(address(testSuite));
        assertEq(basket.balanceOf(address(testSuite)), initialBalance + 1e18);
    }
}
