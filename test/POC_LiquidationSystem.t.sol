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

contract POC_LiquidationSystem is StdCheats, Test {
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig helperConfig;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;
    uint256 deployerKey;

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
        ERC20Mock(weth).mint(liquidator, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(liquidator, STARTING_USER_BALANCE);
        ERC20Mock(weth).mint(address(dsce), 1_000_000 ether);
    }

    function testLiquidationSystem() external {
        console.log(unicode"🕛 Starting POC testLiquidationSystem");
        console.log("First, we will add 1e18 WETH @ %s USD/WETH (8 decimals) to mint 1000e18 DSC for the user %s",
            uint256(MockV3Aggregator(ethUsdPriceFeed).latestAnswer()),
            user);
        console.log("It is overcollateraized at 200%");
        vm.startPrank(user);
        console.log("User %s has:", user);
        console.log("%s weth", ERC20Mock(weth).balanceOf(user));
        console.log("%s DSC", dsc.balanceOf(user));
        console.log("Adding the collateral and minting...");
        ERC20Mock(weth).approve(address(dsce), 1 ether);
        dsce.depositCollateralAndMintDsc(weth, 1 ether, 1000 ether);
        console.log("User %s has:", user);
        console.log("%s weth", ERC20Mock(weth).balanceOf(user));
        console.log("%s DSC", dsc.balanceOf(user));
        console.log("Current user %s health factor: %s", user, dsce.getHealthFactor(user));
        dsc.approve(address(dsce), 100000 ether);

        console.log("Let's reduce WETH value in the oracle to $1/weth");
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1e8);
        console.log("Updated WETH oracle value to %s USD/WETH (8 decimals)", uint256(MockV3Aggregator
        (ethUsdPriceFeed).latestAnswer()));
        console.log("Current user %s health factor: %s", user, dsce.getHealthFactor(user));
        // How is possible to not be liquiditable when 1 weth = 1 USD if we started at $2000 = 1 weth????
        console.log("Is liquiditable? %s", dsce.getHealthFactor(user) >= dsce.getMinHealthFactor());
        vm.stopPrank();
    }
}
