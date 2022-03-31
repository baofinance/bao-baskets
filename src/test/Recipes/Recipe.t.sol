pragma solidity ^0.7.0;

import "ds-test/test.sol";
import "../../Recipes/Recipe.sol";
import "../BasketsTestSuite.sol";
import "./RecipeConfiguration.sol";

contract RecipeTest is DSTest {
    BasketsTestSuite public testSuite;
    RecipeConfigurator public recipeConfigurator;
    event log_named_uint(uint);
    
    function setUp() public {
        testSuite = new BasketsTestSuite();
        recipeConfigurator = new RecipeConfigurator(address(testSuite.recipe()),address(testSuite));
    }
    
    function testMint() public {
        Recipe recipe = testSuite.recipe();
        IERC20(testSuite.basket()).approve(address(recipe),type(uint256).max);
        uint[] memory mintAmounts = new uint[](2);
       
        mintAmounts[0] = 1e18;
	mintAmounts[1] = 1000e18;

        for (uint256 i = 0; i < mintAmounts.length; i++) {
            (uint256 mintPrice, uint16[] memory dexIndex) = recipe.getPricePie(testSuite.basket(), mintAmounts[i]);
            emit log_named_uint("mintPrice: ",mintPrice);
	    emit log_named_uint("dexIndex: ",dexIndex[0]);
  	
 	    recipe.toPie{value: mintPrice}(
                testSuite.basket(),
                mintAmounts[i],
                dexIndex
            );
        }
    }
}
