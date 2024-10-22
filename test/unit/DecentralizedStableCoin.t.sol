//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../Mocks/ERC20Mock.sol";

contract TestDSC is Test {
    // error DSCEngine__NeedMoreThanZero();
    DecentralizedStableCoin decentralizedStableCoin;
    DSCEngine dscEngine;
    DeployDSC deployDSC;
    HelperConfig config;
    address ethUSDPriceFee;
    address weth;
    address public fieldPlayer = makeAddr("fieldPlayer");

    function setUp() external {
        deployDSC = new DeployDSC();
        // vm.prank(fieldPlayer);
        (decentralizedStableCoin, dscEngine, config) = deployDSC.run();
        (ethUSDPriceFee,, weth,,) = config.activeNetworkConfig();
        fieldPlayer = decentralizedStableCoin.owner();
    }

    ///////////////////////////////////
    // DSC Engin Tests ////////////////
    ///////////////////////////////////

    function testGetUsedValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dscEngine.getUsdValue(weth, ethAmount);

        assertEq(expectedUsd, actualUsd);
    }

    function testRevertIfCollateralZero() public {
        vm.startPrank(fieldPlayer);
        ERC20Mock(weth).approveInternal(address(dscEngine), fieldPlayer, 10 ether);

        vm.expectRevert(DSCEngine.DSCEngine__NeedMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    ///////////////////////////////////
    //Decentralized Stable Coin Tests//
    ///////////////////////////////////
    function testAmountZeroRevert() public {
        vm.expectRevert();
        decentralizedStableCoin.burn(0);
    }

    function testBalanceAmountIsLessThanExpectedAmount() public {
        console.log(fieldPlayer);
        vm.prank(fieldPlayer);
        decentralizedStableCoin.mint(fieldPlayer, 3000000000000000000);
        vm.expectRevert();
        decentralizedStableCoin.burn(2000000000000000000);
    }

    function testMintingTokens() public {
        vm.prank(fieldPlayer);
        bool isMinted = decentralizedStableCoin.mint(fieldPlayer, 2000e18);
        assertEq(2000e18, decentralizedStableCoin.balanceOf(fieldPlayer));
        assert(isMinted);
    }

    function testmintAmountShouldGreaterThanZero() public {
        vm.prank(fieldPlayer);
        vm.expectRevert();
        decentralizedStableCoin.mint(address(this), 0);
    }

    function testAddressShouldNotBeZero() public {
        vm.prank(fieldPlayer);
        vm.expectRevert();
        decentralizedStableCoin.mint(address(0), 1000000);
    }

    function testBurningTokens() public {
        vm.prank(fieldPlayer);
        decentralizedStableCoin.mint(fieldPlayer, 2000e18);
        vm.prank(fieldPlayer);
        decentralizedStableCoin.burn(1000e18);
        assertEq(decentralizedStableCoin.balanceOf(fieldPlayer), 1000e18);
    }
}
