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
    address btcUSDPriceFee;
    address weth;
    address wbtc;
    address public fieldPlayer = makeAddr("fieldPlayer");
    uint256 constant public AMOUNT_COLLATERAL = 10 ether;
    uint256 constant public AMOUNT_TO_MINT = 100 ether;
    uint256 constant public STARTING_BALANCE = 20 ether;

    function setUp() external {
        deployDSC = new DeployDSC();
        // vm.prank(fieldPlayer);
        (decentralizedStableCoin, dscEngine, config) = deployDSC.run();
        (ethUSDPriceFee,btcUSDPriceFee, weth, wbtc,) = config.activeNetworkConfig();
        fieldPlayer = decentralizedStableCoin.owner();
        ERC20Mock(weth).mint(fieldPlayer,  STARTING_BALANCE);
        ERC20Mock(wbtc).mint(fieldPlayer,  STARTING_BALANCE);
    }

    ///////////////////////////////////
    // constructor Tests //////////////
    ///////////////////////////////////
    address[] public tokenAddress;
    address[] public priceFeedAddress;

    function testRevertsIfTokenLengthDoesnotMactchPriceFee () public{
        tokenAddress.push(weth);
        priceFeedAddress.push(ethUSDPriceFee);
        priceFeedAddress.push(ethUSDPriceFee);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressAndPriceFeedAddressesLengthMustBeSame.selector);
        new DSCEngine(tokenAddress, priceFeedAddress,address(decentralizedStableCoin));
    }

    function testGetTokenAmountFormUSD() public view{
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        // 2000 / 100
        uint256 pirceInWei = dscEngine.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(expectedWeth,pirceInWei);

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


    function testRevertWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("Random Token","RAN", fieldPlayer, 1002 ether);
        vm.startPrank(fieldPlayer);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dscEngine.depositCollateral(address(ranToken), 10 ether);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(fieldPlayer);
        ERC20Mock(weth).approve(address(dscEngine),AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDespositedWithoutMinting()  public depositedCollateral {
        uint256 userBalance = decentralizedStableCoin.balanceOf(fieldPlayer);
        console.log(userBalance);
        assertEq(userBalance, 0);
    }

    function testCanDepositCollateralAndAccountInfo() public depositedCollateral{
        (uint256 totalDSCMinted, uint256 collateralValueInUsd)  = dscEngine.getAccontInformation(fieldPlayer);

        uint256 expectectedTotalDscMinted = 0;
        uint256 expectedDepositedAmmount= dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDSCMinted, expectectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositedAmmount);
    }

    modifier depositedCollateralAndMintDSC() {
        vm.startPrank(fieldPlayer);
        ERC20Mock(weth).approve(address(dscEngine),AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL,AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedCollateral() public depositedCollateralAndMintDSC{
        uint256 userBalance = decentralizedStableCoin.balanceOf(fieldPlayer);
        assertEq(userBalance, AMOUNT_TO_MINT);
    }

    function testRevertsIfMinitedAmountZero() public {
        vm.startPrank(fieldPlayer);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDsc(weth,AMOUNT_COLLATERAL,AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__NeedMoreThanZero.selector);
        dscEngine.mintDsc(0);
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
