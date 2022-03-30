pragma solidity ^0.7.0;

import "ds-test/test.sol";
import "../../Recipes/Recipe.sol";
import "../BasketsTestSuite.sol";

contract RecipeTest is DSTest {
    BasketsTestSuite public testSuite;

    function setUp() public {
        testSuite = new BasketsTestSuite();
    }

    function testMint() public {
        Recipe recipe = testSuite.recipe();
        IERC20(testSuite.basket()).approve(address(recipe),type(uint256).max);
        uint[] memory mintAmounts = new uint[](3);
        mintAmounts[0] = 0;
        mintAmounts[1] = 100;
        mintAmounts[2] = 1e18;

        for (uint256 i = 0; i < mintAmounts.length; i++) {
            (uint256 mintPrice, uint16[] memory dexIndex) = recipe.getPricePie(testSuite.basket(), mintAmounts[i]);

            recipe.bake(
            testSuite.basket(),
            mintPrice,
            mintAmounts[i],
            _dexIndex
            );
        }
    }
}