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

contract POC_BurnAccounting is StdCheats, Test {
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
        ERC20Mock(weth).mint(liquidator, 100000 ether);
        ERC20Mock(wbtc).mint(liquidator, STARTING_USER_BALANCE);
    }

    function testBurnAccounting() external {
        console.log("Setting weth Price",
            uint256(MockV3Aggregator(ethUsdPriceFeed).latestAnswer()),
            user);
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), 10 ether);
        dsce.depositCollateralAndMintDsc(weth, 1 ether, 1000);
        
        // testing with burnDsc()
        dsc.approve(address(dsce), 1000 );
        console.log("user DSC balance is %s",dsc.balanceOf(user));
        console.log("asserting userbalance to be = 1000:"); 
        assertEq(dsc.balanceOf(user), 1000);
        console.log("calling burnDsc, burning 1000 DSC, the entire user balance"); 
        dsce.burnDsc(1000);
        console.log("asserting userbalance to be = 0 since all DSC was burned"); 
        assertEq(dsc.balanceOf(user), 0);
        vm.stopPrank();

    }

    function testFailBurnAccounting() external {

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), 100000 ether);
        dsce.depositCollateralAndMintDsc(weth, 1 ether, 1000 ether);
        dsc.approve(address(dsce), 100000 ether);
        vm.stopPrank();


        //Testing with liquidate()
        vm.startPrank(liquidator);
        dsc.approve(address(dsce), 10000000000000000000000000 ether);
        ERC20Mock(weth).approve(address(dsce), 100000 ether);
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(200000000000);
        dsce.depositCollateralAndMintDsc(weth, 10000 ether, 1000 ether);
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(199999999999);
        console.log("price 1999$", uint256(MockV3Aggregator
        (ethUsdPriceFeed).latestAnswer()));
        console.log("user DSC balance is %s",dsc.balanceOf(user));
        console.log("Calling the liquidate function for the full debt amount" );
        dsce.liquidate(weth, user, 1000 ether);
        console.log("after being liquidited, the DSC of user should be 0 since he no longer has any collateral");
        console.log("asserting the user balance of DSC to be 0"); 
        assertEq(dsc.balanceOf(user),0);

    } 
}
