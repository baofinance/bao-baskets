import "ds-test/test.sol";
import "../../Recipes/Recipe.sol";
import "../BasketsTestSuite.sol";

contract RecipeTest is DSTest {
    Recipe recipe;
    BasketsTestSuite public testSuite;

    //Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    function setUp() public {
        //Deploy Recipe
        recipe = new Recipe(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
        0x08a2b7D713e388123dc6678168656659d297d397,
        0x51801401e1f21c9184610b99B978D050a374566E,
        0xF5BCE5077908a1b7370B9ae04AdC565EBd643966,
        0x2cBA6Ab6574646Badc84F0544d05059e57a5dc42);
    }
}