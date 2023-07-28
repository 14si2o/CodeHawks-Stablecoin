// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {DeployDSC} from "../script/DeployDSC.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract POC_BonusSystem is StdCheats, Test {
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig helperConfig;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;
    uint256 deployerKey;
    uint256 beforeBalance;
    uint256 afterBalance;

    address user = makeAddr("user");
    address liquidator = makeAddr("liquidator");

    uint256 constant STARTING_USER_BALANCE = 1.1 ether;

    function setUp() public {
        DeployDSC deployer = new DeployDSC();
        (dsc, dsce, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, deployerKey) = helperConfig.activeNetworkConfig();
        if (block.chainid == 31337) {
            vm.deal(user, STARTING_USER_BALANCE);
            vm.deal(liquidator, STARTING_USER_BALANCE);
        }
        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(weth).mint(liquidator, 10 ether);
        ERC20Mock(wbtc).mint(liquidator, STARTING_USER_BALANCE);
    }

    function testBonusSystem() external {
        console.log("First, we will add 1e18 WETH @ %s USD/WETH (8 decimals) to mint 1000e18 DSC for the user %s",
            uint256(MockV3Aggregator(ethUsdPriceFeed).latestAnswer()),
            user);

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), 100000 ether);
        dsce.depositCollateralAndMintDsc(weth, 1 ether, 1000 ether);
        console.log("User %s has:", user);
        console.log("%s DSC", dsc.balanceOf(user));
        console.log("%s USD value of weth", dsce.getUsdValue(weth,1 ether));
        console.log("%s current collateralisation ratio", dsce.getUsdValue(weth,1 ether)/dsc.balanceOf(user));
        console.log("Current user %s health factor: %s", user, dsce.getHealthFactor(user));
        console.log("Is liquiditable? %s", dsce.getHealthFactor(user) < dsce.getMinHealthFactor());        
        dsc.approve(address(dsce), 100000 ether);
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(200000000000);
        console.log("Updated WETH oracle value to 200000000000 which give a 200% collateralisation rate", uint256(MockV3Aggregator
        (ethUsdPriceFeed).latestAnswer()));
        vm.stopPrank();

        //Liquidate at 110% collateralisation 
        vm.startPrank(liquidator);
        dsc.approve(address(dsce), 10000000000000000000000000 ether);
        ERC20Mock(weth).approve(address(dsce), 10 ether);
        dsce.depositCollateralAndMintDsc(weth, 5 ether, 1000 ether);
        console.log("User %s has:", liquidator);
        console.log("%s DSC", dsc.balanceOf(liquidator));
        beforeBalance = ERC20Mock(weth).balanceOf(liquidator);
        console.log("%s USD value of weth", dsce.getUsdValue(weth,1 ether));

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(110000000000);
        console.log("Updated WETH oracle value to 110000000000 which give a 110% collateralisation rate", uint256(MockV3Aggregator
        (ethUsdPriceFeed).latestAnswer()));
        console.log("%s current collateralisation ratio", dsce.getUsdValue(weth,1 ether)*100/dsc.balanceOf(user));
        console.log("Current user %s health factor: %s", user, dsce.getHealthFactor(user));
        console.log("Is liquiditable? %s", dsce.getHealthFactor(user) < dsce.getMinHealthFactor());
        console.log("Calling liquidate function for the full debt amount");
        dsce.liquidate(weth, user, 1000 ether);
        afterBalance = ERC20Mock(weth).balanceOf(liquidator);
        console.log("before weth balance %s",  beforeBalance);
        console.log("after weth balance %s", afterBalance);
        console.log(" Liquidate function working as expected %s", (afterBalance - beforeBalance));
    }

    function testFailBonusSystem() external {
        console.log(unicode"🕛 Starting POC testLiquidationSystem");
        console.log("First, we will add 1e18 WETH @ %s USD/WETH (8 decimals) to mint 1000e18 DSC for the user %s",
            uint256(MockV3Aggregator(ethUsdPriceFeed).latestAnswer()),
            user);
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), 100000 ether);
        dsce.depositCollateralAndMintDsc(weth, 1 ether, 1000 ether);
        dsc.approve(address(dsce), 100000 ether);
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(200000000000);
        console.log("Updated WETH oracle value to 200000000000 which give a 200% collateralisation rate", uint256(MockV3Aggregator
        (ethUsdPriceFeed).latestAnswer()));
        vm.stopPrank();


        //Liquidate at 109.99999999999% collateralisation 
        vm.startPrank(liquidator);
        dsc.approve(address(dsce), 10000000000000000000000000 ether);
        ERC20Mock(weth).approve(address(dsce), 10 ether);
        dsce.depositCollateralAndMintDsc(weth, 5 ether, 1000 ether);
        console.log("User %s has:", liquidator);
        console.log("%s DSC", dsc.balanceOf(liquidator));
        beforeBalance = ERC20Mock(weth).balanceOf(liquidator);
        console.log("%s USD value of weth", dsce.getUsdValue(weth,1 ether));
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(10999999999);
        console.log("Updated WETH oracle value to 10999999999 which give a 109.99999999999% collateralisation rate", uint256(MockV3Aggregator
        (ethUsdPriceFeed).latestAnswer()));
        console.log("Calling liquidate function for the full debt amount");
        dsce.liquidate(weth, user, 1000 ether);

    }
}
