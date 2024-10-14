//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 */
contract DSCEngine is ReentrancyGuard {
    error DSCEngine__NeedMoreThanZero();
    error DSCEngine__TokenAddressAndPriceFeedAddressesLengthMustBeSame();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorIsBelowMinimum(uint256 healthFactor);
    error DSCEngine__MintFailed();

    uint256 private constant ADDITIONAL_FEE_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposite;
    mapping(address user => uint256 amountDscToMinted) private s_DSCMinted;
    address[] private s_collateralTokens;
    DecentralizedStableCoin private immutable i_DSCADDRESS;

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressAndPriceFeedAddressesLengthMustBeSame();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_DSCADDRESS = DecentralizedStableCoin(dscAddress);
    }

    function depositCollateralAndMintDsc() external {}

    /**
     * @param tokenCollateralAddress The address of token to deposit as collateral
     * @param amountCollateral The Total collateral amount want to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposite[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        // if they minted too much ($150 DSC, $100)

        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_DSCADDRESS.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDscs() external {}

    function liquidate() external {}

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDSCMinted, uint256 collateralInValueUsd)
    {
        totalDSCMinted = s_DSCMinted[user];
        collateralInValueUsd = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        // total DSC minted
        // total collateral VALUE
        (uint256 totalDSCMinted, uint256 collateralInValueUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralInValueUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        //
        return (collateralAdjustedForThreshold * PRECISION) / totalDSCMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);

        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsBelowMinimum(userHealthFactor);
        }
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposite[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFee = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFee.latestRoundData();
        // 1 Eth = $1000
        // we will get in return 1000 * 1e8 (Becuase usdt has 8 decimals)
        // we will explicitly add 10(1e10) more decimals here in order to get exact value
        // after it all we will divide the whole equation  by 1e18 in order to get value in decimals
        return ((uint256(price) * ADDITIONAL_FEE_PRECISION) * amount) / PRECISION;
    }
}

// Ethereun mainnet
// 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419 Eth / USD
// 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c BTC / USD

// Sepolia Testnet
// 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43 BTC / USD
// 0x694AA1769357215DE4FAC081bf1f309aDC325306 Eth / USD
