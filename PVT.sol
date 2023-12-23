/*
█▀█ ▄▀█ █▄█ █░█ █▀▀ █▀█ ▀█▀ █ █▀ █▀▀
█▀▀ █▀█ ░█░ ▀▄▀ ██▄ █▀▄ ░█░ █ ▄█ ██▄

▀█▀ █░█ █▀▀   █▀▀ █░█ ▀█▀ █░█ █▀█ █▀▀  
░█░ █▀█ ██▄   █▀░ █▄█ ░█░ █▄█ █▀▄ ██▄  

█▀█ █▀▀
█▄█ █▀░

▄▀█ █▀▄ █░█ █▀▀ █▀█ ▀█▀ █ █▀ █ █▄░█ █▀▀
█▀█ █▄▀ ▀▄▀ ██▄ █▀▄ ░█░ █ ▄█ █ █░▀█ █▄█

*Payvertise - Efficient, innovative revenue sharing in digital ads using blockchain.
*Owner cant mint, changetax, or blacklist
*Permanently fixed 1% Community tax
*Manual burning will be done by the team.

##OUR CHANNELS##
twitter: https://twitter.com/payvertise_
telegram chat: https://t.me/payvertisechat
telegram ann: https://t.me/payvertiseann
github: https://github.com/payvertise

##TOKENOMICS###
Total supply: 100,000,000 $PVT
Decimals: 18
Tax: 1%
*/

// SPDX-License-Identifier: MIT

import "./ERC20.sol";
import "./Ownable.sol";
import "./SafeERC20.sol";
import "./EnumerableSet.sol";

// File: PVT.sol
pragma solidity =0.8.19;

contract PAYVERTISE is ERC20, Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

	event Trade(address pair, uint256 amount, uint side, uint256 circulatingSupply, uint timestamp);

    bool public feeEnabled = false;

    mapping(address => bool) public isFeeExempt;
    mapping(address => bool) public canAddLiquidityBeforeLaunch;

    uint256 private advertisingFee;
    uint256 private totalFee;
    uint256 public feeDenominator = 10000;

    uint256 public advertisingFeeBuy = 100;
    uint256 public totalFeeBuy = 100;

    uint256 public advertisingFeeSell = 100;
    uint256 public totalFeeSell = 100;
	
    uint256 public launchedAt;
    uint256 public launchedAtTimestamp;
	
    address public constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
	address public ADVERTISING_WALLET;

    EnumerableSet.AddressSet private _pairs;

    constructor() ERC20("PAYVERTISE", "PVT") {
        uint256 _totalSupply = 100_000_000 * 1e18;
        canAddLiquidityBeforeLaunch[_msgSender()] = true;
        isFeeExempt[msg.sender] = true;
        isFeeExempt[address(this)] = true;
        _mint(_msgSender(), _totalSupply);
    }



    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        return _pvtTransfer(_msgSender(), to, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(sender, spender, amount);
        return _pvtTransfer(sender, recipient, amount);
    }

    function _pvtTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        
        if (!canAddLiquidityBeforeLaunch[sender]) {
            require(launched(), "Project Not yet started");
        }

        bool shouldTakeAdvertisingFee = (!isFeeExempt[sender] && !isFeeExempt[recipient]) && launched() && feeEnabled;
        uint side = 0;
        address pair_ = recipient;
        // Set Fees
        if (isPair(sender)) {
            buyFees();
            side = 1;
            pair_ = sender;

		} else if (isPair(recipient)) {
            sellFees();
            side = 2;
        } else {
            shouldTakeAdvertisingFee = false; //dont take fee for wallet to wallet token transfers
        }

        uint256 amountReceived = shouldTakeAdvertisingFee ? takeAdvertisingFee(sender, amount) : amount;
        _transfer(sender, recipient, amountReceived);

        if (side > 0) {
            emit Trade(pair_, amount, side, getCirculatingSupply(), block.timestamp);
        }
        return true;
    }

    function launched() internal view returns (bool) {
        return launchedAt != 0;
    }

    function buyFees() internal {
        advertisingFee = advertisingFeeBuy;
        totalFee = totalFeeBuy;
    }

    function sellFees() internal {
        advertisingFee = advertisingFeeSell;
        totalFee = totalFeeSell;
    }

    function takeAdvertisingFee(address sender, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = (amount * totalFee) / feeDenominator;
        _transfer(sender, ADVERTISING_WALLET, feeAmount);
        return amount - feeAmount;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return totalSupply() - balanceOf(BURN_ADDRESS) - balanceOf(ZERO_ADDRESS);
    }
	
	function getMinterLength() public view returns (uint256) {
        return _pairs.length();
    }

    function getPair(uint256 index) public view returns (address) {
        require(index <= _pairs.length() - 1, "index out of bounds");
        return _pairs.at(index);
    }
	
	function isPair(address account) public view returns (bool) {
        return _pairs.contains(account);
    }


    
	/*** ADMIN FUNCTIONS ***/
    function launch() public onlyOwner {
        require(launchedAt == 0, "Already launched");
        launchedAt = block.number;
        launchedAtTimestamp = block.timestamp;
    }

    function rescueToken(address tokenAddress) external onlyOwner {
	    //prevent dev from self-withdraw
		require(tokenAddress != address(this), "Owner Cant withdraw own tokens");
        IERC20(tokenAddress).safeTransfer(msg.sender,IERC20(tokenAddress).balanceOf(address(this)));
    }

    function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
        isFeeExempt[holder] = exempt;
    }    
	
	function setPresaleWallet(address holder, bool exempt) external onlyOwner {
        canAddLiquidityBeforeLaunch[holder] = exempt;
    }

    function setFeeSettings(bool _enabled) external onlyOwner {
        feeEnabled = _enabled;
    }
	
	function setAdvertisingWallet(address _advertisingwallet) external onlyOwner {
        ADVERTISING_WALLET = _advertisingwallet;
    }

    function addPair(address pair) public onlyOwner returns (bool) {
        require(pair != address(0), "pair is the zero address");
        return _pairs.add(pair);
    }

    function delPair(address pair) public onlyOwner returns (bool) {
        require(pair != address(0), "pair is the zero address");
        return _pairs.remove(pair);
    }
	
}