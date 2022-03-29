pragma solidity ^0.8.0;

import "../Diamond/BasketFacet.sol";
import "../Diamond/CallFacet.sol";
import "../Diamond/DiamondCutFacet.sol";
import "../Diamond/DiamondLoupeFacet.sol";
import "../Diamond/ERC20Facet.sol";
import "../Diamond/OwnershipFacet.sol";
import "../BasketRegistry.sol";
import "../LendingRegistry.sol";
import "../Diamond/Diamond.sol";
import "../BasketFactoryContract.sol";
import "../Interfaces/IDiamondCut.sol";
import { LendingLogicKashi } from "../Strategies/KashiLending/LendingLogicKashi.sol";
import { LendingManager } from "../LendingManager.sol";
import { Recipe } from "../Recipes/Recipe.sol";
import { IUniswapV2Router01 } from "../Interfaces/IUniRouter.sol";
import "ds-test/test.sol";

interface Cheats {
    function deal(address who, uint256 amount) external;
    function startPrank(address sender) external;
    function stopPrank() external;
}

/**
 * Helper contract for this project's test suite
 */
contract BasketsTestSuite is DSTest {

    // Foundry Cheat Codes
    Cheats public cheats;

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
    LendingManager public lendingManager;
    LendingLogicKashi public lendingLogicKashi;

    // Recipe
    Recipe public recipe;

    // Test Basket
    address public basket;

    // Constants
    address[] public TEST_BASKET_TOKENS;

    address immutable public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address immutable public SUSHI_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address immutable public BENTO_BOX = 0xF5BCE5077908a1b7370B9ae04AdC565EBd643966;
    address immutable public SUSHI_EXACT_SWAPPER = 0xB527C5295c4Bc348cBb3a2E96B2494fD292075a7;

    bytes32 immutable public KASHI_PROTOCOL = 0x000000000000000000000000d3f07ea86ddf7baebefd49731d7bbd207fedc53b;

    constructor () {
        // Give our test suite some ETH
        cheats = Cheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        cheats.deal(address(this), 1000 ether);

        // Set the tokens that we'll put in our test basket
        TEST_BASKET_TOKENS.push(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

        deployProtocol();
    }

    function deployProtocol() private {
        // Deploy Facets
        basketFacet = new BasketFacet();
        callFacet = new CallFacet();
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
        lendingLogicKashi = new LendingLogicKashi(address(lendingRegistry), KASHI_PROTOCOL, BENTO_BOX);

        // Create Test Basket
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 100000000;
        uint256 initialSupply = 100 ether;

        buyTokens(tokenAmounts);
        approveTokens(address(basketFactory));

        basketFactory.bakeBasket(TEST_BASKET_TOKENS, tokenAmounts, initialSupply, "testBasket", "Test Basket");
        basket = basketFactory.baskets(0);

        // Deploy Lending Manager
        lendingManager = new LendingManager(address(lendingRegistry), basket);

        // Deploy Recipe
        recipe = new Recipe(WETH, address(lendingRegistry), address(basketRegistry), BENTO_BOX, SUSHI_EXACT_SWAPPER);

        // Set privileges
        CallFacet basketCF = CallFacet(basket);
        basketCF.addCaller(address(this));
        basketCF.addCaller(address(lendingManager));

        // Configure Lending
        lendingRegistry.setProtocolToLogic(KASHI_PROTOCOL, address(lendingLogicKashi));
        lendingRegistry.setWrappedToProtocol(0x2cBA6Ab6574646Badc84F0544d05059e57a5dc42, KASHI_PROTOCOL); // Kashi Medium Risk V1
        lendingRegistry.setWrappedToUnderlying(0x2cBA6Ab6574646Badc84F0544d05059e57a5dc42, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC
        lendingRegistry.setUnderlyingToProtocolWrapped(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, KASHI_PROTOCOL, 0x2cBA6Ab6574646Badc84F0544d05059e57a5dc42);

        // Add basket to basket registry
        basketRegistry.addBasket(basket);
    }

    function buyTokens(uint256[] memory _tokenAmounts) private {
        require(_tokenAmounts.length == TEST_BASKET_TOKENS.length, "Error: Incorrect length of token amounts array.");

        IUniswapV2Router01 router = IUniswapV2Router01(SUSHI_ROUTER);
        for (uint8 i; i < TEST_BASKET_TOKENS.length;) {
            address[] memory route = _getRoute(WETH, TEST_BASKET_TOKENS[i]);
            uint256 amountIn = router.getAmountsIn(_tokenAmounts[i], route)[0];

            router.swapExactETHForTokens{value: amountIn}(
                _tokenAmounts[i],
                route,
                address(this),
                block.timestamp
            );

            unchecked { ++i; }
        }
    }

    function approveTokens(address spender) private {
        for (uint8 i; i < TEST_BASKET_TOKENS.length;) {
            IERC20 token = IERC20(TEST_BASKET_TOKENS[i]);
            token.approve(spender, type(uint256).max);

            unchecked { ++i; }
        }
    }

    function _getRoute(address a, address b) private returns (address[] memory route) {
        route = new address[](2);
        route[0] = a;
        route[1] = b;
    }
}