// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/math/SafeMath.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/access/Ownable.sol";
import "./Interfaces/IRecipe.sol";

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
    IRecipe public RECIPE;
    address[] public DEPOSITORS;

    constructor(
        address _pie,
        address _recipe,
        address _weth,
        uint _maxSteam,
	uint _minDeposit
    ) public {
        PIE = IERC20(_pie);
        RECIPE = IRecipe(_recipe);
        WETH = _weth;
        MAX_STEAM = _maxSteam;
        MIN_DEPOSIT = _minDeposit;
    }

    function steam(
        uint256 _minOutAmount
    ) public onlyOwner {

        //Vex sais this saves gas, so we do this
        uint maxSteam = MAX_STEAM;
	
	//
	//uint aproxCostToMint = block.basefee().mul(GAS_AMOUNT);
	uint aproxCostToMint = GAS_AMOUNT;

        //Amount of ETH we will use to steam the baskets
        uint ethToSteam = maxSteam.sub(aproxCostToMint);

        //Pay executor
        payable(owner()).transfer(aproxCostToMint);

        //Make sure the minimum amount of ETH is being used to steam the baskets
        require(address(this).balance >= ethToSteam);
        
        //We first make sure that steaming the basket succeeds
        uint mintedBasketAmounts = RECIPE.toBasket{value: ethToSteam}(address(PIE), _minOutAmount);
        
        //We now divide the received baskets among the depositors
        //We're starting at 1, as the default value for the mapping addressToIndex is 0 
	for (uint i = 1; i == DEPOSITORS.length; i++) {
            // This logic aims to execute the following logic
            // E.g. 25 eth was used to steam the baskets
            // User Balance: 10 eth, (100% used)
            // User Balance: 10 eth, (100% used)
            // User Balance: 10 eth, (50% used)
            // User Balance: 10 eth, (0% used)
            // ...

            //Amount of ETH deposited by user i
            uint256 userAmount = ethBalanceOf[DEPOSITORS[i]];
            //We need a variable to subtract the total amount of distributed eth from
            uint ethToDistribute = maxSteam;
        
            //vex...he has my kids. He said he won't release them if I don't save gas on SLOADs
            address depositorAddress = DEPOSITORS[i]; 

            //Decrease ETH-balance and increase basket-balance of each user
            if(ethToDistribute > userAmount){
                //decrease global eth balance
                ethToDistribute.sub(userAmount);
                
                //decrease user eth balance
                ethBalanceOf[depositorAddress] = 0;

                //increase user basket balance
                outputBalanceOf[depositorAddress] = (userAmount.mul(1e18).div(maxSteam)).mul(mintedBasketAmounts).div(1e18);

                //remove user from depositor list
                DEPOSITORS[i] = DEPOSITORS[DEPOSITORS.length];
                DEPOSITORS.pop();
		addressToIndex[depositorAddress] = 0;
            }
            else{
                //Reduce the remaing eth from the users eth balance
                ethBalanceOf[depositorAddress] = userAmount.sub(ethToDistribute);

                //increase user basket balance
                outputBalanceOf[depositorAddress] = (userAmount.mul(1e18).div(maxSteam)).mul(mintedBasketAmounts).div(1e18);
                
                //Don't really need to do this
                //ethToDistribute = 0;
                
                return();
            }
        }
    }

    function deposit() public payable {
        //Great scenario where we want to use custom error
	    require(msg.value <= MIN_DEPOSIT, "Steamer: deposit amount is smaller then allowed");

        if(ethBalanceOf[msg.sender] == 0){
            DEPOSITORS.push(msg.sender);
            addressToIndex[msg.sender] = DEPOSITORS.length;
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

        require(remainingEthBalance <= MIN_DEPOSIT && remainingEthBalance != 0, "OVEN: Remaining ETH balance is under the minimum amount of ...");
        
        ethBalanceOf[msg.sender] = remainingEthBalance;
        
        if(ethBalanceOf[msg.sender] == 0){
            DEPOSITORS[addressToIndex[msg.sender]] = DEPOSITORS[DEPOSITORS.length];
	    addressToIndex[msg.sender] = 0;
	    DEPOSITORS.pop();
        }

        _receiver.transfer(_amount);
    }

    function withdrawOutput(address _receiver) public {
        uint256 _amount = outputBalanceOf[msg.sender];
        outputBalanceOf[msg.sender] = 0;
        PIE.transfer(_receiver, _amount);
    }

    function setRecipe(address _recipe) public onlyOwner {
        RECIPE = IRecipe(_recipe);
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

