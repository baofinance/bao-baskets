pragma solidity ^0.7.0;

import "forge-std/Test.sol";
import "../../Recipes/Recipe.sol";
import "../BasketsTestSuite.sol";
import "./RecipeConfiguration.sol";
import "../../Recipes/CurveRecipe.sol";

contract CurveRecipeTest is Test {

    BasketsTestSuite public testSuite;
    CurveRecipe public curveRecipe;

    function setUp() public {
        testSuite = new BasketsTestSuite();

        IERC20 USDC = IERC20(testSuite.constants().USDC());
        USDC.approve(address(testSuite.curveRecipe()), type(uint256).max);
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 1e9;
        address[] memory _tokens = new address[](1);
        _tokens[0] = testSuite.constants().USDC();
        testSuite.buyTokens(_amounts, _tokens);

        testSuite.cheats().startPrank(address(testSuite));
        USDC.transfer(address(this), USDC.balanceOf(address(testSuite)));
        testSuite.cheats().stopPrank();

        emit log_named_uint("USDC Balance", USDC.balanceOf(address(this)));
    }

    function testMint2() public {
        CurveRecipe recipe = testSuite.curveRecipe();
        IERC20 basket = IERC20(testSuite.bSTBL());

        basket.approve(address(recipe), type(uint256).max);
        uint[] memory mintAmounts = new uint[](2);

        mintAmounts[0] = 1e18;
        mintAmounts[1] = 10e18;

        for (uint256 i = 0; i < mintAmounts.length; i++) {
            uint256 initialBalance = address(this).balance;

            uint256 mintPrice = recipe.getPrice(address(basket), mintAmounts[i]);

            emit log_named_uint("Recipe Price", mintPrice);

            recipe.bake(
                address(basket),
                mintPrice,
                mintAmounts[i]
            );

            uint256 basketBalance = basket.balanceOf(address(this));
            assertGe(basketBalance, mintAmounts[i]);
            assertEq(mintPrice, initialBalance - address(this).balance);
        }
    }

    function testRedeem() public {
        CurveRecipe recipe = testSuite.curveRecipe();
        IExperiPie basket = IExperiPie(testSuite.bSTBL());

        uint256 mintPrice = recipe.getPrice(address(basket), 1e18);

        IERC20(testSuite.constants().USDC()).approve(address(recipe), type(uint256).max);

        recipe.bake(
            address(basket),
            mintPrice,
            1e18
        );

        (address[] memory _tokens, uint256[] memory _amounts) = basket.calcTokensForAmountExit(1e18);
        basket.exitPool(1e18);

        for (uint8 i; i < _tokens.length; i++) {
            assertGt(_amounts[i], 0);

            uint256 balance = IERC20(_tokens[i]).balanceOf(address(this));
            assertEq(balance, _amounts[i]);
        }
    }

    receive() external payable {}
}
