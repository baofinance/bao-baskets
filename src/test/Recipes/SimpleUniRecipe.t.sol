pragma solidity ^0.7.0;

import "forge-std/Test.sol";
import "../../Recipes/Recipe.sol";
import "../BasketsTestSuite.sol";
import "./RecipeConfiguration.sol";

contract SimpleUniRecipeTest is Test {

    IERC20 public USDC;
    BasketsTestSuite public testSuite;
    SimpleUniRecipe public uniRecipe;

    function setUp() public {
        testSuite = new BasketsTestSuite();

        USDC = IERC20(testSuite.constants().USDC());
        USDC.approve(address(testSuite.uniRecipe()), type(uint256).max);
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 1e11;
        address[] memory _tokens = new address[](1);
        _tokens[0] = testSuite.constants().USDC();
        testSuite.buyTokens(_amounts, _tokens);

        testSuite.cheats().startPrank(address(testSuite));
        USDC.transfer(address(this), USDC.balanceOf(address(testSuite)));
        testSuite.cheats().stopPrank();
    }

    function testMint() public {
        SimpleUniRecipe recipe = testSuite.uniRecipe();
        IERC20 basket = IERC20(testSuite.bSTBL());

        basket.approve(address(recipe), type(uint256).max);
        uint[] memory mintAmounts = new uint[](2);

        mintAmounts[0] = 1e18;
        mintAmounts[1] = 1e19;

        for (uint256 i = 0; i < mintAmounts.length; i++) {
            uint256 initialBalance = USDC.balanceOf(address(this));

            uint256 mintPrice = recipe.getPrice(address(basket), mintAmounts[i]);

            recipe.bake(
                address(basket),
                mintPrice,
                mintAmounts[i]
            );

            uint256 basketBalance = basket.balanceOf(address(this));
            assertGe(basketBalance, mintAmounts[i]);
            assertEq(mintPrice, initialBalance - USDC.balanceOf(address(this)));
        }
    }

    function testRedeem() public {
        SimpleUniRecipe recipe = testSuite.uniRecipe();
        IExperiPie basket = IExperiPie(testSuite.bSTBL());

        uint256 mintPrice = recipe.getPrice(address(basket), 10e18);

        IERC20(testSuite.constants().USDC()).approve(address(recipe), type(uint256).max);

        recipe.bake(
            address(basket),
            mintPrice,
            10e18
        );

        (address[] memory _tokens, uint256[] memory _amounts) = basket.calcTokensForAmountExit(10e18);
        basket.exitPool(10e18);

        for (uint8 i; i < _tokens.length; i++) {
            assertGt(_amounts[i], 0);

            uint256 balance = IERC20(_tokens[i]).balanceOf(address(this));
            assertEq(balance, _amounts[i]);
        }
    }

    receive() external payable {}
}
