pragma solidity ^0.7.0;

import "forge-std/Test.sol";
import {SimpleUniRecipe} from "../../Recipes/SimpleUniRecipe.sol";
import "../BasketsTestSuite.sol";

contract SteamerTest is Test {

    BasketsTestSuite public testSuite;
    Steamer public steamer;
    SimpleUniRecipe public recipe;
    Cheats cheats;

    function setUp() public {
        testSuite = new BasketsTestSuite();
        cheats = testSuite.cheats();
        steamer = testSuite.bSTBLSteamer();
        recipe = testSuite.uniRecipe();
    }
 
    function testSteamerDeposit() public {
        steamer.deposit{value : 1e18}();
        assertEq(steamer.ethBalanceOf(address(this)), 1e18);
    }

    function testSteamerWithdrawETH() public {
        uint256 initialBalance = address(this).balance;

        steamer.deposit{value : 1e18}();
        steamer.withdrawETH(1e18, payable(address(this)));
        assertEq(steamer.ethBalanceOf(address(this)), 0);
        assertEq(address(this).balance, initialBalance);
    }

    function testSteamerSteam() public {

	address user1 = 0x56Eddb7aa87536c09CCc2793473599fD21A8b17F;
	address user2 = 0x9696f59E4d72E237BE84fFD425DCaD154Bf96976;
	address user3 = 0xDFd5293D8e347dFe59E90eFd55b2956a1343963d;

        //User 1
	cheats.startPrank(user1);
        steamer.deposit{value : (10e18)}();
        cheats.stopPrank();
        //User 2
        cheats.startPrank(user2);
        steamer.deposit{value : (10e18)}();
        cheats.stopPrank();
        //User 3
        cheats.startPrank(user3);
        steamer.deposit{value : (10e18)}();
        cheats.stopPrank();
        //cheats.startPrank(0x564286362092D8e7936f0549571a803B203aAceD);
        //steamer.deposit{value : (10e18)}();
        //cheats.stopPrank();
        
	//get Basket reference
        IERC20 basket = IERC20(testSuite.bSTBL());
 
	//Steam 30 basket tokens 
        steamer.steam(30 ether);

	//TODO: Pre calculate amount of ETH that the given basket token amounts should cost, and check if the correct of ETH is being spent
	
	//Make sure Steamer has received 30 basket tokens
	assertEq(basket.balanceOf(address(steamer)), 30 ether,"Steamer did not receive correct amount of basket tokens");
	//Every minted token should be accounted for	
	assertEq(basket.balanceOf(address(steamer)),steamer.outputBalanceOf(user1)+steamer.outputBalanceOf(user2)+steamer.outputBalanceOf(user3));
	//Eth balances should reflect total eth held by the steamer
	assertEq(address(steamer).balance,steamer.ethBalanceOf(user1)+steamer.ethBalanceOf(user2)+steamer.ethBalanceOf(user3));	
    }

    receive() external payable {}
}
