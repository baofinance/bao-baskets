// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/math/SafeMath.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/access/Ownable.sol";
import {SimpleUniRecipe} from "./Recipes/SimpleUniRecipe.sol";

contract Steamer is Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) public ethBalanceOf;
    mapping(address => uint256) public outputBalanceOf;
    mapping(address => uint256) public addressToIndex;

    address immutable WETH;
    IERC20 immutable public PIE;

    uint public MAX_STEAM;
    uint public MIN_DEPOSIT;
    uint public GAS_AMOUNT;
    SimpleUniRecipe public RECIPE;
    address[] public DEPOSITORS;

    event log_named_uint(string key, uint val);
    event log_named_address(string key, address val);

    constructor(
        address _pie,
        address payable _recipe,
        address _weth,
        uint _maxSteam,
	uint _minDeposit
    ) public {
        PIE = IERC20(_pie);
        RECIPE = SimpleUniRecipe(_recipe);
        WETH = _weth;
        MAX_STEAM = _maxSteam;
        MIN_DEPOSIT = _minDeposit;
    }

    function steam(
        uint256 _minOutAmount
    ) public {

        //Vex sais this saves gas, so we do this
        uint maxSteam = MAX_STEAM;

	//Pre-mint eth balance
	uint originalEthBalance = address(this).balance;

	//We first make sure tha)t steaming the basket succeeds
	RECIPE.toBasket{value: maxSteam}(address(PIE), _minOutAmount);
	uint mintedBasketAmounts = PIE.balanceOf(address(this));       

	//TODO: Implement GAS cost sharing, requires update to ^0.8.x

        //uint aproxCostToMint = block.basefee().mul(GAS_AMOUNT);
        //uint aproxCostToMint = GAS_AMOUNT;
        //Amount of ETH we will use to steam the baskets
        //uint ethToSteam = maxSteam.sub(aproxCostToMint);
	//Pay executor
        //payable(owner()).transfer(aproxCostToMint);

	//Amount of ETH used to mint the basket tokens
        uint spendEth = originalEthBalance.sub(address(this).balance);
        //We need a variable from which we can subtract the amount of distributed eth
	uint ethToDistribute = spendEth;

        //We now divide the received baskets among the depositors
        //We're starting at 1, as the default value for the mapping addressToIndex is 0 
	uint depositorAmount = DEPOSITORS.length; 
	for (uint i; i < depositorAmount; i++) {
            // This logic aims to execute the following logic
            // E.g. 25 eth was used to steam the baskets
            // User Balance: 10 eth, (100% used)
            // User Balance: 10 eth, (100% used)
            // User Balance: 10 eth, (50% used)
            // User Balance: 10 eth, (0% used)
            // ...
            //Amount of ETH deposited by user i
            uint256 userAmount = ethBalanceOf[DEPOSITORS[0]];
        
            //vex...he has my kids. He said he won't release them if I don't save gas on SLOADs
            address depositorAddress = DEPOSITORS[0];
	    //Decrease ETH-balance and increase basket-balance of each user
            if(ethToDistribute > userAmount){
                //decrease global eth balance
                ethToDistribute = ethToDistribute.sub(userAmount);
                //decrease user eth balance
                ethBalanceOf[depositorAddress] = 0;

                //increase user basket balance
                outputBalanceOf[depositorAddress] = (userAmount.mul(1e18).div(spendEth)).mul(mintedBasketAmounts).div(1e18);
		//remove user from depositor list
                DEPOSITORS[0] = DEPOSITORS[DEPOSITORS.length-1];
                DEPOSITORS.pop();
		addressToIndex[depositorAddress] = 0;
            }
            else{
                //Reduce the remaing eth from the users eth balance
                ethBalanceOf[depositorAddress] = userAmount.sub(ethToDistribute);

                //increase user basket balance
                outputBalanceOf[depositorAddress] = (ethToDistribute.mul(1e18).div(spendEth)).mul(mintedBasketAmounts).div(1e18);
                
                //Don't really need to do this
                //ethToDistribute = 0;
                return();
            }
        }
    }

    function deposit() public payable {
        //Great scenario where we want to use custom error
	require(msg.value >= MIN_DEPOSIT, "Steamer: deposit amount is smaller then allowed");

        if(ethBalanceOf[msg.sender] == 0){
            DEPOSITORS.push(msg.sender);
            addressToIndex[msg.sender] = DEPOSITORS.length-1;
        }

        ethBalanceOf[msg.sender] = ethBalanceOf[msg.sender].add(msg.value);
    }

    function withdrawAll(address payable _receiver) external {
        withdrawAllETH(_receiver);
        withdrawOutput(_receiver);
    }

    function withdrawAllETH(address payable _receiver) public {
        withdrawETH(ethBalanceOf[msg.sender], _receiver);
    }

    function withdrawETH(uint256 _amount, address payable _receiver)
        public
    {
        uint remainingEthBalance = ethBalanceOf[msg.sender].sub(_amount);

        require(remainingEthBalance >= MIN_DEPOSIT || remainingEthBalance == 0, "STEAMER: Remaining ETH balance is under the minimum amount of ...");
        
        ethBalanceOf[msg.sender] = remainingEthBalance;
        
        if(ethBalanceOf[msg.sender] == 0){
	    if(DEPOSITORS.length == 1){
		addressToIndex[msg.sender] = 0;
                DEPOSITORS.pop();
	    }
	    else{
                DEPOSITORS[addressToIndex[msg.sender]] = DEPOSITORS[DEPOSITORS.length];
	        addressToIndex[msg.sender] = 0;
	        DEPOSITORS.pop();
            }
	}

        _receiver.transfer(_amount);
    }

    function withdrawOutput(address _receiver) public {
        uint256 _amount = outputBalanceOf[msg.sender];
        outputBalanceOf[msg.sender] = 0;
        PIE.transfer(_receiver, _amount);
    }

    function setRecipe(address payable _recipe) public onlyOwner {
        RECIPE = SimpleUniRecipe(_recipe);
    }

    function saveToken(address _token) external onlyOwner {
        require(_token != address(PIE), "INVALID_TOKEN");

        IERC20 token = IERC20(_token);

        token.transfer(
            owner(),
            token.balanceOf(address(this))
        );
    }

    receive() external payable {
        deposit();
    }
}

