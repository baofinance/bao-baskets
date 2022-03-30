pragma solidity ^0.7.0;

import "ds-test/test.sol";
import "../../Recipes/Recipe.sol";
import "../BasketsTestSuite.sol";

contract RecipeTest is DSTest {
    BasketsTestSuite public testSuite;

    function setUp() public {
        testSuite = new BasketsTestSuite();
    }
}