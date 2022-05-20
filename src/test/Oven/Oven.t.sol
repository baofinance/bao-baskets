pragma solidity ^0.7.0;

import "forge-std/Test.sol";
import "../../Recipes/Recipe.sol";
import "../BasketsTestSuite.sol";

contract SteamerTest is Test {

    BasketsTestSuite public testSuite;
    Steamer public steamer;
    Recipe public recipe;
    Cheats cheats;

    function setUp() public {
        testSuite = new BasketsTestSuite();
        cheats = testSuite.cheats();
	//startHoax(address(testSuite));
        //steamer = testSuite.bSTBLSteamer();
        //recipe = testSuite.recipe();
    }

    function testGasUsage() public {

	address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
	
	steamer = new Steamer(DAI,
        DAI,
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
        20 ether,
        1e17);
	
	//User 1
	cheats.startPrank(0x56Eddb7aa87536c09CCc2793473599fD21A8b17F);
        steamer.deposit{value : (10e18)}();
	cheats.stopPrank();
	//User 2
	cheats.startPrank(0x9696f59E4d72E237BE84fFD425DCaD154Bf96976);
        steamer.deposit{value : (10e18)}();
	cheats.stopPrank();
	//User 3
	cheats.startPrank(0xDFd5293D8e347dFe59E90eFd55b2956a1343963d);
	steamer.deposit{value : (10e18)}();
        cheats.stopPrank();
	//User 4
        //cheats.startPrank(0x564286362092D8e7936f0549571a803B203aAceD);
        //steamer.deposit{value : (10e18)}();
        //cheats.stopPrank();
	//getBasket tokens
	address[] memory token = new address[](1);
	uint[] memory amount = new uint[](1);
	token[0] = DAI;
	amount[0] = 1000 ether;
	testSuite.getTokensFromHolders(amount, token);
	//Send basketTokens to steamer
	IERC20(DAI).transfer(address(steamer),1000 ether);
	//Steam
        emit log_named_uint("Before Steamer Checkpoint",0);
 	steamer.steam(1000);
        emit log_named_uint("Final Checkpoint",0);	
    }
 
/*
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
    }*/
}
