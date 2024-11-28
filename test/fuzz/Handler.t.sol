//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../Mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../Mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;

    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;

    ERC20Mock public weth;
    ERC20Mock public wbtc;

    address[] public userWithCollateralDeposited;
    uint256 public timesMintIsCalled;
    uint256 public timeDepositCollateralCalled;

    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
        dsce = _engine;
        dsc = _dsc;

        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
        btcUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(wbtc)));
    }

    function mintDSC(uint256 amount, uint256 addressSeed) public {
        if (userWithCollateralDeposited.length == 0) return;
        address sender = userWithCollateralDeposited[addressSeed % userWithCollateralDeposited.length];
        (uint256 totalDSCMinted, uint256 collateralValueInUsd) = dsce.getAccontInformation(sender);
        int256 maxDSCToMint = ((int256(collateralValueInUsd)) / 2) - int256(totalDSCMinted);
        timesMintIsCalled++;
        if (maxDSCToMint < 0) {
            return;
        }
        amount = bound(amount, 0, uint256(maxDSCToMint));
        vm.startPrank(sender);
        dsce.mintDsc(amount);
        vm.stopPrank();
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        amountCollateral = bound(amountCollateral, 1, type(uint96).max);
        ERC20Mock collateral = _getCollateralSFromSeed(collateralSeed);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);
        dsce.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        userWithCollateralDeposited.push(msg.sender);
        timeDepositCollateralCalled++;
    }

    function redeemCollaterl(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralSFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(msg.sender, address(collateral));

        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }
        vm.prank(msg.sender);
        dsce.redeemCollateral(address(collateral), amountCollateral);
    }

    function _getCollateralSFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
