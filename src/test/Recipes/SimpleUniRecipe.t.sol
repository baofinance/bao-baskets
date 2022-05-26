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

    function testMint(uint _basketAmount) public {
        testSuite.cheats().assume(_basketAmount >= 1e18 && _basketAmount <= 1e21);
	//uint256 _basketAmount = 10e18;

        SimpleUniRecipe recipe = testSuite.uniRecipe();
        IERC20 basket = IERC20(testSuite.bSTBL());

        basket.approve(address(recipe), type(uint256).max);

        uint256 initialBalance = USDC.balanceOf(address(this));
        uint256 mintPrice = recipe.getPrice(address(basket), _basketAmount);
        uint256 mintPriceBuffered = mintPrice+1;

	//Depositing a bit more then predicted
        recipe.bake(
            address(basket),
            mintPriceBuffered,
            _basketAmount
        );
        
        assertApproxEq(basket.balanceOf(address(this)), _basketAmount,1);
        assertEq(mintPriceBuffered, initialBalance - USDC.balanceOf(address(this)));
    }

    function testMintEth(uint _basketAmount) public {
        testSuite.cheats().assume(_basketAmount >= 1e18 && _basketAmount <= 1e21);
	//uint256 _basketAmount = 10e18;

        SimpleUniRecipe recipe = testSuite.uniRecipe();
        IERC20 basket = IERC20(testSuite.bSTBL());

        basket.approve(address(recipe), type(uint256).max);

        uint256 mintPrice = recipe.getPriceEth(address(basket), _basketAmount);
	//increase mintprice by 5%
	uint256 mintPriceBuffered = mintPrice * 105e16 / 1e18;
        testSuite.cheats().deal(address(this), mintPriceBuffered);
        uint256 initialBalance = address(this).balance;

        recipe.toBasket{ value: mintPriceBuffered }(
            address(basket),
            _basketAmount
        );
	assertApproxEq(basket.balanceOf(address(this)), _basketAmount,1);
        assertEq(mintPriceBuffered, initialBalance - address(this).balance);
    }

    function testRedeem() public {
        SimpleUniRecipe recipe = testSuite.uniRecipe();
        IExperiPie basket = IExperiPie(testSuite.bSTBL());

        uint256 mintPrice = recipe.getPrice(address(basket), 10e18);

        IERC20(testSuite.constants().USDC()).approve(address(recipe), type(uint256).max);

        recipe.bake(
            address(basket),
            mintPrice+1,
            10e18
        );

        (address[] memory _tokens, uint256[] memory _amounts) = basket.calcTokensForAmountExit(10e18);
        basket.exitPool(10e18);

        for (uint8 i; i < _tokens.length; i++) {
            assertGt(_amounts[i], 0);

            uint256 balance = IERC20(_tokens[i]).balanceOf(address(this));
            assertApproxEq(balance, _amounts[i],1);
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
