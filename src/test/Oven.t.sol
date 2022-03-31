pragma solidity ^0.7.0;

import "ds-test/test.sol";
import "../Recipes/Recipe.sol";
import "./BasketsTestSuite.sol";

contract RecipeTest is DSTest {
    BasketsTestSuite public testSuite;

    function setUp() public {
        testSuite = new BasketsTestSuite();
        testSuite.cheats().deal(address(this), 1000 ether);
    }
    
    function testOvenDeposit() public{

    }

    function testOvenWithdraw() public{

    }

    function testOvenBake() public{

    }

    /////////////////////////
    ///UTILITY FUNCTION//////
    /////////////////////////

    function fillOven() public {
    
    }

    function emptyOven() public {

    }

    function bakeOven() public {

    }
}
