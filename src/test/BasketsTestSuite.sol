pragma solidity ^0.7.0;

import "forge-std/Test.sol";
import {Constants} from "./constants.sol";
import "../Diamond/BasketFacet.sol";
import "../Diamond/CallFacet.sol";
import "../Diamond/DiamondCutFacet.sol";
import "../Diamond/DiamondLoupeFacet.sol";
import "../Diamond/ERC20Facet.sol";
import "../Diamond/OwnershipFacet.sol";
import "../BasketRegistry.sol";
import {Oven} from "../Oven.sol";
import {OvenFactoryContract} from "../OvenFactory.sol";
import "../LendingRegistry.sol";
import "../Diamond/Diamond.sol";
import "../BasketFactoryContract.sol";
import "../Interfaces/IDiamondCut.sol";
import {LendingLogicAaveV2} from "../Strategies/LendingLogicAaveV2.sol";
import {LendingLogicCompound} from "../Strategies/LendingLogicCompound.sol";
import {StakingLogicSushi} from "../Strategies/StakingLogicSushi.sol";
import {LendingManager} from "../LendingManager.sol";
import {IUniswapV2Router01} from "../Interfaces/IUniRouter.sol";
import "../Recipes/SimpleUniRecipe.sol";
import "../Recipes/Recipe.sol";

interface Cheats {
    function deal(address who, uint256 amount) external;

    function startPrank(address sender) external;

    function stopPrank() external;

    function assume(bool condition) external;
}

pragma experimental ABIEncoderV2;

/**
 * Helper contract for this project's test suite
 */
contract BasketsTestSuite is Test {

    // Foundry Cheat Codes
    Cheats public cheats;

    //Mainnet Constants
    Constants public constants;

    // Facets
    BasketFacet public basketFacet;
    CallFacet public callFacet;
    DiamondCutFacet public cutFacet;
    DiamondLoupeFacet public loupeFacet;
    ERC20Facet public erc20Facet;
    OwnershipFacet public ownershipFacet;

    // Basket Registry
    BasketRegistry public basketRegistry;

    // Lending Registry
    LendingRegistry public lendingRegistry;

    // Diamond
    Diamond public diamond;

    // Factory
    BasketFactoryContract public basketFactory;

    // Lending Manager & Logic
    LendingManager public bSLendingManager;
    LendingLogicAaveV2 public lendingLogicAave;
    LendingLogicCompound public lendingLogicCompound;
    StakingLogicSushi public stakingLogicSushi;

    // Recipe
    Recipe public recipe;
    SimpleUniRecipe public uniRecipe;

    // OvenFactory
    OvenFactoryContract public ovenFactory;

    // Oven
    Oven public bSTBLOven;

    // Test Basket
    address public bSTBL;

    // Constants
    address[] public bSTBL_BASKET_TOKENS;
    //Lending Option Config
    address public SUSHI_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address public BENTO_BOX = 0xF5BCE5077908a1b7370B9ae04AdC565EBd643966;
    address public KASHI_MEDIUM_RISK = 0x2cBA6Ab6574646Badc84F0544d05059e57a5dc42;
    bytes32 public XSUSHI_PROTOCOL = 0x0000000000000000000000000000000000000000000000000000000000000004;
    bytes32 public KASHI_PROTOCOL = 0x0000000000000000000000000000000000000000000000000000000000000003;
    bytes32 public AAVE_PROTOCOL = 0x0000000000000000000000000000000000000000000000000000000000000002;
    bytes32 public COMP_PROTOCOL = 0x0000000000000000000000000000000000000000000000000000000000000001;

    constructor () {
        // Give our test suite some ETH
        cheats = Cheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        cheats.deal(address(this), 1000 ether);

        //Get Constants
        constants = new Constants();

        // Set the tokens that we'll put in our test baskets
        bSTBL_BASKET_TOKENS.push(constants.DAI());
        bSTBL_BASKET_TOKENS.push(constants.RAI());
        bSTBL_BASKET_TOKENS.push(constants.USDC());

        deployProtocol();
    }

    // ---------------------------------
    // SET UP
    // ---------------------------------

    function deployProtocol() private {
        // Deploy Facets
        basketFacet = new BasketFacet();
        callFacet = new CallFacet();
        erc20Facet = new ERC20Facet();
        cutFacet = new DiamondCutFacet();
        loupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();

        // Deploy Basket Registry
        basketRegistry = new BasketRegistry();

        // Deploy Lending Registry
        lendingRegistry = new LendingRegistry();

        // Deploy Diamond
        diamond = new Diamond();

        // Deploy Factory & Set Facets
        basketFactory = new BasketFactoryContract();
        basketFactory.setDiamondImplementation(address(diamond));

        bytes4[] memory erc20FacetCutSelectors = new bytes4[](16);
        erc20FacetCutSelectors[0] = 0xeedfca5f;
        erc20FacetCutSelectors[1] = 0x06fdde03;
        erc20FacetCutSelectors[2] = 0xc47f0027;
        erc20FacetCutSelectors[3] = 0x95d89b41;
        erc20FacetCutSelectors[4] = 0xb84c8246;
        erc20FacetCutSelectors[5] = 0x313ce567;
        erc20FacetCutSelectors[6] = 0x40c10f19;
        erc20FacetCutSelectors[7] = 0x9dc29fac;
        erc20FacetCutSelectors[8] = 0x095ea7b3;
        erc20FacetCutSelectors[9] = 0xd73dd623;
        erc20FacetCutSelectors[10] = 0x66188463;
        erc20FacetCutSelectors[11] = 0xa9059cbb;
        erc20FacetCutSelectors[12] = 0x23b872dd;
        erc20FacetCutSelectors[13] = 0xdd62ed3e;
        erc20FacetCutSelectors[14] = 0x70a08231;
        erc20FacetCutSelectors[15] = 0x18160ddd;
        IDiamondCut.FacetCut memory erc20FacetCut = IDiamondCut.FacetCut(address(erc20Facet), IDiamondCut.FacetCutAction.Add, erc20FacetCutSelectors);
        basketFactory.addFacet(erc20FacetCut);

        bytes4[] memory basketFacetCutSelectors = new bytes4[](34);
        basketFacetCutSelectors[0] = 0xd48bfca7;
        basketFacetCutSelectors[1] = 0x5fa7b584;
        basketFacetCutSelectors[2] = 0xeb770d0c;
        basketFacetCutSelectors[3] = 0xe586a4f0;
        basketFacetCutSelectors[4] = 0xe5a583a9;
        basketFacetCutSelectors[5] = 0xecb0116a;
        basketFacetCutSelectors[6] = 0xef512424;
        basketFacetCutSelectors[7] = 0xad293cf2;
        basketFacetCutSelectors[8] = 0x5a0a3d82;
        basketFacetCutSelectors[9] = 0xd908c3e5;
        basketFacetCutSelectors[10] = 0x8a8257dd;
        basketFacetCutSelectors[11] = 0x9d3f7dd4;
        basketFacetCutSelectors[12] = 0xfff3087c;
        basketFacetCutSelectors[13] = 0x366254e8;
        basketFacetCutSelectors[14] = 0x34e7a19f;
        basketFacetCutSelectors[15] = 0xbe1d24ad;
        basketFacetCutSelectors[16] = 0xec9c2b39;
        basketFacetCutSelectors[17] = 0x5d44c9cb;
        basketFacetCutSelectors[18] = 0x7e5852d9;
        basketFacetCutSelectors[19] = 0xaecb9356;
        basketFacetCutSelectors[20] = 0x560ad134;
        basketFacetCutSelectors[21] = 0xd3e15747;
        basketFacetCutSelectors[22] = 0x47786d37;
        basketFacetCutSelectors[23] = 0xe3d670d7;
        basketFacetCutSelectors[24] = 0xaa6ca808;
        basketFacetCutSelectors[25] = 0x554d578d;
        basketFacetCutSelectors[26] = 0x371babdc;
        basketFacetCutSelectors[27] = 0x23817b8e;
        basketFacetCutSelectors[28] = 0xddbcb5fa;
        basketFacetCutSelectors[29] = 0xf50ab0de;
        basketFacetCutSelectors[30] = 0x9baf58d2;
        basketFacetCutSelectors[31] = 0x3809283a;
        basketFacetCutSelectors[32] = 0x6ed93dd0;
        basketFacetCutSelectors[33] = 0xf47c84c5;
        IDiamondCut.FacetCut memory basketFacetCut = IDiamondCut.FacetCut(address(basketFacet), IDiamondCut.FacetCutAction.Add, basketFacetCutSelectors);
        basketFactory.addFacet(basketFacetCut);

        bytes4[] memory ownershipFacetCutSelectors = new bytes4[](2);
        ownershipFacetCutSelectors[0] = 0xf2fde38b;
        ownershipFacetCutSelectors[1] = 0x8da5cb5b;
        IDiamondCut.FacetCut memory ownershipFacetCut = IDiamondCut.FacetCut(address(ownershipFacet), IDiamondCut.FacetCutAction.Add, ownershipFacetCutSelectors);
        basketFactory.addFacet(ownershipFacetCut);

        bytes4[] memory callFacetCutSelectors = new bytes4[](8);
        callFacetCutSelectors[0] = 0x747293fb;
        callFacetCutSelectors[1] = 0xeef21cd2;
        callFacetCutSelectors[2] = 0x30c9473c;
        callFacetCutSelectors[3] = 0xbd509fd5;
        callFacetCutSelectors[4] = 0x98a9884d;
        callFacetCutSelectors[5] = 0xcb6e7a89;
        callFacetCutSelectors[6] = 0xdd8d4c40;
        callFacetCutSelectors[7] = 0xbf29b3a7;
        IDiamondCut.FacetCut memory callFacetCut = IDiamondCut.FacetCut(address(callFacet), IDiamondCut.FacetCutAction.Add, callFacetCutSelectors);
        basketFactory.addFacet(callFacetCut);

        bytes4[] memory diamondCutFacetSelectors = new bytes4[](1);
        diamondCutFacetSelectors[0] = 0x1f931c1c;
        IDiamondCut.FacetCut memory diamondFacetCut = IDiamondCut.FacetCut(address(diamond), IDiamondCut.FacetCutAction.Add, diamondCutFacetSelectors);
        basketFactory.addFacet(diamondFacetCut);

        bytes4[] memory loupeFacetCutSelectors = new bytes4[](5);
        loupeFacetCutSelectors[0] = 0x7a0ed627;
        loupeFacetCutSelectors[1] = 0xadfca15e;
        loupeFacetCutSelectors[2] = 0x52ef6b2c;
        loupeFacetCutSelectors[3] = 0xcdffacc6;
        loupeFacetCutSelectors[4] = 0x01ffc9a7;
        IDiamondCut.FacetCut memory loupeFacetCut = IDiamondCut.FacetCut(address(loupeFacet), IDiamondCut.FacetCutAction.Add, loupeFacetCutSelectors);
        basketFactory.addFacet(loupeFacetCut);

        // Deploy Lending Strategies
        lendingLogicAave = new LendingLogicAaveV2(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9, 0);
        lendingLogicCompound = new LendingLogicCompound(address(lendingRegistry), COMP_PROTOCOL);
        stakingLogicSushi = new StakingLogicSushi(address(lendingRegistry), XSUSHI_PROTOCOL);

        // Create Test Basket
        uint256[] memory bSTBLTokenAmounts = new uint256[](3);

        //bSTBL
        bSTBLTokenAmounts[0] = 3333333333333333333;
        bSTBLTokenAmounts[1] = 1103752750000000000;
        bSTBLTokenAmounts[2] = 3333333;

        uint256 initialSTBLSupply = 1 ether;

        buyTokens(bSTBLTokenAmounts, bSTBL_BASKET_TOKENS);
        approveTokens(address(basketFactory), bSTBL_BASKET_TOKENS);

        basketFactory.bakeBasket(bSTBL_BASKET_TOKENS, bSTBLTokenAmounts, initialSTBLSupply, "bSTBL", "bSTBL Test Basket");
        bSTBL = basketFactory.baskets(0);

        // Deploy Lending Manager
        bSLendingManager = new LendingManager(address(lendingRegistry), bSTBL);

        // Deploy Recipes
        recipe = new Recipe(constants.WETH(), address(lendingRegistry), address(basketRegistry), BENTO_BOX, KASHI_MEDIUM_RISK);
        uniRecipe = new SimpleUniRecipe(
            address(lendingRegistry),
            address(basketRegistry),
            0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, // Uniswap V3 Router
            0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6
        );

        // Deploy OvenFactory
        ovenFactory = new OvenFactoryContract();
        ovenFactory.setDefaultController(address(this));
        bSTBLOven = ovenFactory.CreateOven(address(bSTBL), address(recipe));

        // Set privileges
        CallFacet bSBasketCF = CallFacet(bSTBL);
        bSBasketCF.addCaller(address(this));
        bSBasketCF.addCaller(address(bSLendingManager));

        // Configure Lending
        // xSUSHI (for tests)
        lendingRegistry.setProtocolToLogic(XSUSHI_PROTOCOL, address(stakingLogicSushi));
        lendingRegistry.setWrappedToUnderlying(constants.xSUSHI(), constants.SUSHI());
        lendingRegistry.setUnderlyingToProtocolWrapped(constants.SUSHI(), XSUSHI_PROTOCOL, constants.xSUSHI());

        // bSTBL
        // USDC - AAVE
        lendingRegistry.setProtocolToLogic(AAVE_PROTOCOL, address(lendingLogicAave));
        lendingRegistry.setWrappedToProtocol(constants.aUSDC(), AAVE_PROTOCOL);
        lendingRegistry.setWrappedToUnderlying(constants.aUSDC(), constants.USDC());
        lendingRegistry.setUnderlyingToProtocolWrapped(constants.USDC(), AAVE_PROTOCOL, constants.aUSDC());
        // DAI - AAVE
        lendingRegistry.setWrappedToProtocol(constants.aDAI(), AAVE_PROTOCOL);
        lendingRegistry.setWrappedToUnderlying(constants.aDAI(), constants.DAI());
        lendingRegistry.setUnderlyingToProtocolWrapped(constants.DAI(), AAVE_PROTOCOL, constants.aDAI());
        // RAI - AAVE
        lendingRegistry.setWrappedToProtocol(constants.aRAI(), AAVE_PROTOCOL);
        lendingRegistry.setWrappedToUnderlying(constants.aRAI(), constants.RAI());
        lendingRegistry.setUnderlyingToProtocolWrapped(constants.RAI(), AAVE_PROTOCOL, constants.aRAI());

        // Add basket to basket registry
        basketRegistry.addBasket(bSTBL);

        // Lend USDC into AAVE
        bSLendingManager.lend(constants.USDC(), IERC20(constants.USDC()).balanceOf(bSTBL), AAVE_PROTOCOL);
        // Lend DAI into COMPOUND
        bSLendingManager.lend(constants.DAI(), IERC20(constants.DAI()).balanceOf(bSTBL), AAVE_PROTOCOL);
        // Lend RAI into AAVE
        bSLendingManager.lend(constants.RAI(), IERC20(constants.RAI()).balanceOf(bSTBL), AAVE_PROTOCOL);
    }

    // ---------------------------------
    // HELPER FUNCTIONS
    // ---------------------------------

    function buyTokens(uint256[] memory _tokenAmounts, address[] memory _tokens) public {
        require(_tokenAmounts.length == _tokens.length, "Error: Incorrect length of token amounts array.");

        IUniswapV2Router01 router = IUniswapV2Router01(SUSHI_ROUTER);
        for (uint8 i; i < _tokens.length; i++) {
            address[] memory route = _getRoute(constants.WETH(), _tokens[i]);
            uint256 amountIn = router.getAmountsIn(_tokenAmounts[i], route)[0];

            router.swapExactETHForTokens{value : amountIn}(
                _tokenAmounts[i],
                route,
                address(this),
                block.timestamp
            );
        }
    }

    function getTokensFromHolders(uint[] memory _tokenAmounts, address[] memory _tokens) public {
        require(_tokenAmounts.length == _tokens.length, "Error: Incorrect length of token amounts array.");
        for (uint8 i; i < _tokens.length; i++) {
            address holder = constants.tokenHolders(_tokens[i]);
            uint holderBalance = IERC20(_tokens[i]).balanceOf(holder);
            require(holderBalance >= _tokenAmounts[i], "Error getTokesFromHolders: Holder doesn't have enough token to provide for testing");
            cheats.startPrank(holder);
            IERC20(_tokens[i]).transfer(address(this), _tokenAmounts[i]);
            cheats.stopPrank();
        }
    }

    function approveTokens(address spender, address[] memory _tokens) private {
        for (uint8 i; i < _tokens.length; i++) {
            IERC20 token = IERC20(_tokens[i]);
            token.approve(spender, type(uint256).max);
        }
    }

    function _getRoute(address a, address b) private returns (address[] memory route) {
        route = new address[](2);
        route[0] = a;
        route[1] = b;
    }

    receive() external payable {}
}