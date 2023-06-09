// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title DEX Template
 * @author stevepham.eth and m00npapi.eth
 * @notice Empty DEX.sol that just outlines what features could be part of the challenge (up to you!)
 * @dev We want to create an automatic market where our contract will hold reserves of both ETH and 🎈 Balloons. These reserves will provide liquidity that allows anyone to swap between the assets.
 * NOTE: functions outlined here are what work with the front end of this branch/repo. Also return variable names that may need to be specified exactly may be referenced (if you are confused, see solutions folder in this repo and/or cross reference with front-end code).
 */
contract DEX {
    /* ========== GLOBAL VARIABLES ========== */

    using SafeMath for uint256; //outlines use of SafeMath for uint256 variables
    IERC20 token; //instantiates the imported contract
    uint256 public totalLiquidity;
    mapping (address => uint256) public liquidity;
    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when ethToToken() swap transacted
     */
    event EthToTokenSwap(address sender, string swap, uint256 ethValue, uint256 tokenswapped);

    /**
     * @notice Emitted when tokenToEth() swap transacted
     */
    event TokenToEthSwap(address sender, string swap, uint256 ethvalue, uint256 tokenValue);

    /**
     * @notice Emitted when liquidity provided to DEX and mints LPTs.
     */
    event LiquidityProvided(address sender, uint256 lp, uint256 ethvalue, uint256 tokenvalue);

    /**
     * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
     */
    event LiquidityRemoved(address sender, uint256 amount,uint256 theamount, uint256 tokenvalue);

    /* ========== CONSTRUCTOR ========== */

    constructor(address token_addr) public {
        token = IERC20(token_addr); //specifies the token address that will hook into the interface and be used through the variable 'token'
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice initializes amount of tokens that will be transferred to the DEX itself from the erc20 contract mintee (and only them based on how Balloons.sol is written). Loads contract up with both ETH and Balloons.
     * @param tokens amount to be transferred to DEX
     * @return totalLiquidity is the number of LPTs minting as a result of deposits made to DEX contract
     * NOTE: since ratio is 1:1, this is fine to initialize the totalLiquidity (wrt to balloons) as equal to eth balance of contract.
     */
    function init(uint256 tokens) public payable returns (uint256) {
        require(totalLiquidity == 0, "dex: init already has liquidity");
        totalLiquidity = address(this).balance;
        liquidity[msg.sender] = totalLiquidity;
        require(token.transferFrom(msg.sender, address(this),tokens), "Dex: transact failed");
        return totalLiquidity;
    }

    /**
     * @notice returns yOutput, or yDelta for xInput (or xDelta)
     * @dev Follow along with the [original tutorial](https://medium.com/@austin_48503/%EF%B8%8F-minimum-viable-exchange-d84f30bd0c90) Price section for an understanding of the DEX's pricing model and for a price function to add to your contract. You may need to update the Solidity syntax (e.g. use + instead of .add, * instead of .mul, etc). Deploy when you are done.
     */
    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public view returns (uint256 yOutput) {
        uint256 xInputwithFee = xInput.mul(997);
        uint256 numerator = xInputwithFee.mul(yReserves);
        uint256 denominator = xReserves.mul(1000).add(xInputwithFee);
        return (numerator/denominator);

    }

    /**
     * @notice returns liquidity for a user.
     * NOTE: this is not needed typically due to the `liquidity()` mapping variable being public and having a getter as a result. This is left though as it is used within the front end code (App.jsx).
     * NOTE: if you are using a mapping liquidity, then you can use `return liquidity[lp]` to get the liquidity for a user.
     * NOTE: if you will be submitting the challenge make sure to implement this function as it is used in the tests.
     */
    function getLiquidity(address lp) public view returns (uint256) {
        return liquidity[lp];
    }

    /**
     * @notice sends Ether to DEX in exchange for $BAL
     */
    function ethToToken() public payable returns (uint256 tokenOutput) {
        require(msg.value >0, "not enough eth");
        uint256 ethReserve = address(this).balance.sub(msg.value);
        uint256 token_Reserve = token.balanceOf(address(this));
        uint256 tokenOuput = price(msg.value, ethReserve, token_Reserve);
        require(token.transfer(msg.sender,tokenOuput), "ethtoToken() failed: reverted swap");
        emit EthToTokenSwap(msg.sender, "eth to ballon", msg.value, tokenOuput);
        return tokenOuput;
    }

    /**
     * @notice sends $BAL tokens to DEX in exchange for Ether
     */
    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
        require(tokenInput > 0, "cannot swap zero ");
        uint256 token_Reserve = token.balanceOf(address(this));
        uint256 ethOutput = price(tokenInput, token_Reserve,address(this).balance);
        require(token.transferFrom(msg.sender, address(this), tokenInput), " tokentoETh(): fialed: reverted swap");
        (bool sent, ) = msg.sender.call{value: ethOutput}("");
        require(sent,"couldnt swap, send the back to u");
        emit TokenToEthSwap(msg.sender, "Ballon to eth", ethOutput, tokenInput);
        return ethOutput;

    }

    /**
     * @notice allows deposits of $BAL and $ETH to liquidity pool
     * NOTE: parameter is the msg.value sent with this function call. That amount is used to determine the amount of $BAL needed as well and taken from the depositor.
     * NOTE: user has to make sure to give DEX approval to spend their tokens on their behalf by calling approve function prior to this function call.
     * NOTE: Equal parts of both assets will be removed from the user's wallet with respect to the price outlined by the AMM.
     */
    function deposit() public payable returns (uint256 tokensDeposited) {
        require(msg.value > 0, "cant deposit zero");
        uint256 ethReserve = address(this).balance.sub(msg.value);
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 tokenDeposit;

tokenDeposit = (msg.value.mul(tokenReserve)/ethReserve).add(1);
uint256 liquidityMinted = msg.value.mul(totalLiquidity)/ethReserve;
liquidity[msg.sender] =liquidity[msg.sender].add(liquidityMinted);
totalLiquidity = totalLiquidity.add(liquidityMinted);

require(token.transferFrom(msg.sender, address(this), tokenDeposit));
emit LiquidityProvided(msg.sender, liquidityMinted, msg.value,tokenDeposit);
return tokenDeposit;


    }

    /**
     * @notice allows withdrawal of $BAL and $ETH from liquidity pool
     * NOTE: with this current code, the msg caller could end up getting very little back if the liquidity is super low in the pool. I guess they could see that with the UI.
     */
    function withdraw(uint256 amount) public returns (uint256 eth_amount, uint256 token_amount) {
        require(liquidity[msg.sender] >= amount, "dont have enough to withdraw");
        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethWithdrawn;

        ethWithdrawn = amount.mul(ethReserve)/ totalLiquidity;
        uint256 tokenAmount = amount.mul(tokenReserve)/ totalLiquidity;
        liquidity[msg.sender] = liquidity[msg.sender].sub(amount);
        totalLiquidity = totalLiquidity.sub(amount);
        (bool sent,) = payable(msg.sender).call{value: ethWithdrawn}("");
        require(sent, "withdraw() failed, reverting...");
        require(token.transfer(msg.sender, tokenAmount ));
        emit LiquidityRemoved(msg.sender, amount, ethWithdrawn, tokenAmount);
        return (ethWithdrawn,tokenAmount);
    }
}
