pragma solidity ^0.7.0;

import "forge-std/Test.sol";
import "../../Recipes/Recipe.sol";
import "../BasketsTestSuite.sol";
import "./RecipeConfiguration.sol";

contract SimpleUniRecipeTest is Test {

    IERC20 public DAI;
    BasketsTestSuite public testSuite;
    SimpleUniRecipe public uniRecipe;

    function setUp() public {
        testSuite = new BasketsTestSuite();

        DAI = IERC20(testSuite.constants().DAI());
        DAI.approve(address(testSuite.uniRecipe()), type(uint256).max);
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 1e24; // Get 1 million DAI
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(DAI);
        testSuite.buyTokens(_amounts, _tokens);

        testSuite.cheats().startPrank(address(testSuite));
        DAI.transfer(address(this), DAI.balanceOf(address(testSuite)));
        testSuite.cheats().stopPrank();
    }

    function testMint(uint _basketAmount) public {
        testSuite.cheats().assume(_basketAmount >= 1e18 && _basketAmount <= 1e21);

        SimpleUniRecipe recipe = testSuite.uniRecipe();
        IERC20 basket = IERC20(testSuite.bSTBL());

        basket.approve(address(recipe), type(uint256).max);

        uint256 initialBalance = DAI.balanceOf(address(this));
        uint256 mintPrice = recipe.getPrice(address(basket), _basketAmount);

        recipe.bake(
            address(basket),
            mintPrice,
            _basketAmount
        );

        // Ensure that we received exactly `_basketAmount` basket tokens
        assertEq(basket.balanceOf(address(this)), _basketAmount);
        // Ensure that the recipe only used `mintPrice` DAI to mint `_basketAmount` baskets
        assertEq(mintPrice, initialBalance - DAI.balanceOf(address(this)));
    }

    function testMintEth(uint _basketAmount) public {
        testSuite.cheats().assume(_basketAmount >= 1e18 && _basketAmount <= 1e21);

        SimpleUniRecipe recipe = testSuite.uniRecipe();
        IERC20 basket = IERC20(testSuite.bSTBL());

        basket.approve(address(recipe), type(uint256).max);

        uint256 mintPrice = recipe.getPriceEth(address(basket), _basketAmount);
        testSuite.cheats().deal(address(this), mintPrice);
        uint256 initialBalance = address(this).balance;

        recipe.toBasket{ value: mintPrice }(
            address(basket),
            _basketAmount
        );

        // Ensure that we received exactly `_basketAmount` basket tokens
        assertEq(basket.balanceOf(address(this)), _basketAmount);
        // Ensure that the recipe only used `mintPrice` ETH to mint `_basketAmount` baskets
        assertEq(mintPrice, initialBalance - address(this).balance);
    }

    function testMintRemaining() public {
        uint _basketAmount = 1e19;

        SimpleUniRecipe recipe = testSuite.uniRecipe();
        IERC20 basket = IERC20(testSuite.bSTBL());

        basket.approve(address(recipe), type(uint256).max);

        uint256 initialBalance = DAI.balanceOf(address(this));
        uint256 mintPrice = 1e21; // Send too much DAI
        uint256 _realPrice = recipe.getPrice(address(basket), _basketAmount);

        (uint256 used,) = recipe.bake(
            address(basket),
            mintPrice,
            _basketAmount
        );

        // Ensure that we received exactly `_basketAmount` basket tokens
        assertEq(basket.balanceOf(address(this)), _basketAmount);
        // Ensure that the amount of the input token that was used is correct
        assertEq(used, initialBalance - DAI.balanceOf(address(this)));
        // Ensure that the used amount is less than `mintPrice`, where we intentionally sent too much.
        assertLt(used, mintPrice);
        // Ensure that the amount used is equal to the real price of `_basketAmount` basket tokens.
        assertEq(_realPrice, initialBalance - DAI.balanceOf(address(this)));
    }

    function testMintEthRemaining() public {
        uint _basketAmount = 1e19;

        SimpleUniRecipe recipe = testSuite.uniRecipe();
        IERC20 basket = IERC20(testSuite.bSTBL());

        basket.approve(address(recipe), type(uint256).max);

        uint256 mintPrice = 1e18; // Send too much ETH
        testSuite.cheats().deal(address(this), mintPrice);
        uint256 initialBalance = address(this).balance;

        (uint256 used,) = recipe.toBasket{ value: mintPrice }(
            address(basket),
            _basketAmount
        );

        // Ensure that we received exactly `_basketAmount` basket tokens
        assertEq(basket.balanceOf(address(this)), _basketAmount);
        // Ensure that the amount of the input token that was used is correct
        assertEq(used, initialBalance - address(this).balance);
        // Ensure that the used amount is less than `mintPrice`, where we intentionally sent too much.
        assertLt(used, mintPrice);
    }

    function testRedeem(uint _basketAmount) public {
        testSuite.cheats().assume(_basketAmount >= 1e18 && _basketAmount <= 1e21);

        SimpleUniRecipe recipe = testSuite.uniRecipe();
        IExperiPie basket = IExperiPie(testSuite.bSTBL());

        uint256 mintPrice = recipe.getPrice(address(basket), _basketAmount);

        DAI.approve(address(recipe), type(uint256).max);

        recipe.bake(
            address(basket),
            mintPrice,
            _basketAmount
        );

        (address[] memory _tokens, uint256[] memory _amounts) = basket.calcTokensForAmountExit(_basketAmount);
        basket.exitPool(_basketAmount);

        for (uint8 i; i < _tokens.length; i++) {
            assertGt(_amounts[i], 0);
            assertApproxEq(IERC20(_tokens[i]).balanceOf(address(this)), _amounts[i], 1); // 1 WEI delta threshold
        }
    }

    function assertApproxEq(
        uint256 a,
        uint256 b,
        uint256 maxDelta
    ) internal {
        uint256 delta = a > b ? a - b : b - a;

        if (delta > maxDelta) {
            emit log("Error: a ~= b not satisfied [uint]");
            emit log_named_uint("  Expected", b);
            emit log_named_uint("    Actual", a);
            emit log_named_uint(" Max Delta", maxDelta);
            emit log_named_uint("     Delta", delta);
            fail();
        }
    }

    receive() external payable {}
}
