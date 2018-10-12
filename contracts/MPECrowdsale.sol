pragma solidity ^0.4.24;

import "./MPEToken.sol";
import "openzeppelin-solidity/contracts/crowdsale/distribution/FinalizableCrowdsale.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";

/**
 * @title MPECrowdsale
 * @dev Extension of MintedCrowdsale to handle to crowdsale of the MPEToken
 * @dev the rate logic is changed, now the rate variable is the exchange rate from €uro to ethereum
 * @dev this is done because the price per token during the crowdsale stage is €uro based
 * 
 */
contract MPECrowdsale is FinalizableCrowdsale, Pausable 
{
	using SafeMath for uint256;
	
	uint256 private constant p100        = 100 * 10**18;
	uint256 private constant p10         = 10  * 10**18;
	uint256 private constant precision   = 10**6;
	
	// Setted at deploy time for debug purpose
	uint256 private ICO_START;   	// 1539302400 => 2018-10-12 12:00am (UTC)
	uint256 private ICO_STAGE_2; 	// 1540944000 => 2018-10-31 12:00am (UTC)
	uint256 private ICO_STAGE_3; 	// 1543190400 => 2018-11-26 12:00am (UTC)
	uint256 private ICO_END;     	// 1551139200 => 2019-02-26 12:00am (UTC)
	
	uint256 public constant TOKEN_CAP = 37.5  * 10**6 * 10**18; // 37,50m MPEs total supply
	uint256 public constant CAP_10P   =  3.75 * 10**6 * 10**18; //  3,75m (10%) of the TOKEN_CAP
	uint256 public constant CAP_20P   =  7.5  * 10**6 * 10**18; //  7,50m (20%) of the TOKEN_CAP
	
	address public operator;		// Address of the operator of the Contract for the periodic exchange rate update
	address public walletOWN;		// Address to collet the funds
	
	uint256 public soldToken  = 0;	// Amount of token sold
	uint256 public bonusToken = 0;	// Amount of bonus token provided

	uint256 private tmpSold   = 0;	// temp variable to calculate the token sold during the purchase
	uint256 private tmpBonus  = 0;	// temp variable to calculate the bonus provided during the purchase
	
	enum stage { notStarted, stage1, stage2, stage3, closed }

	uint256 public constant tokenPrice   = 11.5 * 10**18;	// 11,5 €uro x token
	
	uint256 public constant stage1Bonus  = 30   * 10**18;
	uint256 public constant stage2Bonus  = 20   * 10**18;
	uint256 public constant stage3Bonus  = 10   * 10**18;
	
	//event Debug( string msgText, uint256 msgVal);
	event TokenSent(address wallet, uint256 amount, uint256 bonus);
	event WalletOWNUpdated(address oldWallet, address newWallet);
	event OperatorUpdated(address oldOperator, address newOperator);
	event RateUpdated(uint256 oldRate, uint256 newRate);
	
	/**
	 * @dev Throws if called by any account other than the owner or operator.
	 */
	modifier onlyOperator() {
		require( (msg.sender == owner) || (msg.sender == operator) );
		_;
	}
	
	/**
	 * @param _rate       Starting exchange rate €uro/Ethereum
	 * @param _icoStart   Timestamp of the ICO Start
	 * @param _icoStage2  Timestamp of the ICO Stage 2 Start
	 * @param _icoStage3  Timestamp of the ICO Stage 3 Start
	 * @param _icoEnd     Timestamp of the ICO End
	 * @param _operator   Address of the operator of the Contract for the periodic exchange rate update
	 * @param _walletOWN  Address to collet the funds
	 * @param _walletADV1 Address of the 1st advisor to collet the 20% of the token at deploy time
	 * @param _walletADV2 Address of the 2st advisor to collet the 10% of the token at deploy time
	 * @param _walletADV3 Address of the 3st advisor to collet the 20% of the token at finalize time
	 */
	constructor(
			uint256 _rate,
			uint256 _icoStart,
			uint256 _icoStage2,
			uint256 _icoStage3,
			uint256 _icoEnd,
			address _operator,
			address _walletOWN,		
			address _walletADV1,
			address _walletADV2,
			address _walletADV3		
	) 
		public
		Crowdsale(_rate, _walletOWN, ERC20( new MPEToken(TOKEN_CAP) ) )
		TimedCrowdsale(_icoStart, _icoEnd)
	{
		require(_operator   != address(0));
		require(_walletOWN  != address(0));
		require(_walletADV1 != address(0));
		require(_walletADV2 != address(0));
		require(_walletADV3 != address(0));
		
		require(_walletADV1 != _walletADV2 && _walletADV1 != _walletADV3 && _walletADV1 != _walletOWN && _walletADV1 != _operator);
		require(_walletADV2 != _walletADV3 && _walletADV2 != _walletOWN  && _walletADV2 != _operator);
		require(_walletADV3 != _walletOWN  && _walletADV3 != _operator);
		require(_walletOWN  != _operator);
		
		operator    = _operator;
		walletOWN   = _walletOWN;

		ICO_START   = _icoStart;
		ICO_STAGE_2 = _icoStage2;
		ICO_STAGE_3 = _icoStage3;
		ICO_END     = _icoEnd;
		
		token.safeTransfer( _walletADV1, CAP_20P );
		token.safeTransfer( _walletADV2, CAP_10P );
		token.safeTransfer( _walletADV3, CAP_20P );
	}

	/**
	 * @dev add the condition whenNotPaused to the base validation of an incoming purchase
	 * @param _beneficiary Address performing the token purchase
	 * @param _weiAmount Value in wei involved in the purchase
	 */
	function _preValidatePurchase(address _beneficiary, uint256 _weiAmount)
		internal 
		whenNotPaused
	{
		/*
		 *		Calculate how many tokens I'm purchasing
		 */
		tmpSold  = _weiAmount.mul( rate ).div( tokenPrice );
		
		/*
		 *		Minimum 10 tokens 
		 */
		require( tmpSold >= 10 * 10**18);
		
		/*
		 *		During the stage one I can't sold more then 57500 token
		 */
		if( _currentStage() == stage.stage1 )
		{
			require( soldToken.add( tmpSold ) <= 57500 * 10**18 );
		}

		/*
		 *		Calculate the bonus token for the current stage
		 */
		tmpBonus = tmpSold.mul(precision).div(p100).mul( _currentBonus(_currentStage()) ).div(precision);

		/*
		 *		I have sufficient Token ?
		 */
		require( token.balanceOf(this) >= tmpSold.add(tmpBonus) );
		
		super._preValidatePurchase(_beneficiary, _weiAmount);
	}

	/**
	 * @dev Return the current stage of the crowdsale
	 */
	function _currentStage()
		internal
		view
		returns (stage)
	{
		if( now >= ICO_END )     { return stage.closed; }
		if( now >= ICO_STAGE_3 ) { return stage.stage3; }
		if( now >= ICO_STAGE_2 ) { return stage.stage2; }
		if( now >= ICO_START )   { return stage.stage1; }

		return stage.notStarted;
	}
	
	/**
	 * @dev Return the current bonus percentage
	 */
	function _currentBonus(stage _stage)
		internal
		view
		returns (uint256)
	{
		if( _stage == stage.stage3 ) { return stage3Bonus; }
		if( _stage == stage.stage2 ) { return stage2Bonus; }
		if( _stage == stage.stage1 ) { return stage1Bonus; }

		return 0;
	}
	
	/**
	 * @dev Overriding this I can handle the logic of the crowdsale
	 * @param _weiAmount Value in wei to be converted into tokens
	 * @return Number of tokens that can be purchased with the specified _weiAmount
	 */
	function _getTokenAmount(uint256 _weiAmount)
		internal
		view
		returns (uint256) 
	{
		/**
		 * Formula = ( ( wei * ethPriceInEuro / tokenPriceInEuro ) + %bonus )
		 */

		uint256 _t = _weiAmount.mul( rate ).div( tokenPrice );
		
		return _t.add( _t.mul(precision).div(p100).mul( _currentBonus(_currentStage()) ).div(precision) );
	}
	
	/**
	 * @dev Determines how ETH is stored/forwarded on purchases.
	 */
	function _forwardFunds() 
		internal 
	{
		walletOWN.transfer(msg.value);
	}
	
	/**
	 * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid conditions are not met.
	 * @param _beneficiary Address performing the token purchase
	 * @param _weiAmount Value in wei involved in the purchase
	 */
	function _postValidatePurchase(address _beneficiary, uint256 _weiAmount)
		internal
	{
		soldToken  = soldToken.add( tmpSold );
		bonusToken = bonusToken.add( tmpBonus );
		
		super._postValidatePurchase(_beneficiary, _weiAmount);
	}
	
	/**
	 * @dev Finalize the Crowdsale and send the remain token to the owner
	 */
	function finalization() 
		internal 
	{
		uint256 _avail = token.balanceOf(this);
		
		if( _avail > 0 )
		{
			token.safeTransfer( walletOWN, _avail );
		}
		
		super.finalization();
	}
	
	/**
	 * @dev Send Token to the customer that have purchased the token via alternative method (Wire transfer, Credit card, Bitcoin, and so on)
	 * @param _wallet destination address
	 * @param _amount amount of the purchased token
	 * @param _bonus amount of the bonus token for this purchase
	 */
	function sendToken( address _wallet, uint256 _amount, uint256 _bonus ) 
		external 
		onlyOwner 
	{ 
		require(_wallet != address(0)); 
		require(_amount > 0);
		require(_bonus > 0);
		
		/*
		 *		During the stage one I can't sold more then 57500 token
		 */
		if( _currentStage() == stage.stage1 )
		{
			require( soldToken.add( _amount ) <= 57500 );
		}

		/*
		 *		have I sufficient Token ?
		 */
		require( token.balanceOf(this) >= _amount.add(_bonus) );
		
		token.safeTransfer( _wallet, _amount.add(_bonus) );

		soldToken  = soldToken.add( _amount );
		bonusToken = bonusToken.add( _bonus );

		emit TokenSent(_wallet, _amount, _bonus);
	}
	
	// ------------------------------------------------------
	// Owner utility to update wallets, operator, rate, etc
	// ------------------------------------------------------

	/**
	 * @dev Update the wallet OWN address
	 * @param _wallet new wallet address
	 */
	function updateWalletOWN( address _wallet ) 
		external 
		onlyOwner 
	{ 
		require(_wallet != address(0)); 
		require(_wallet != wallet); 
		
		emit WalletOWNUpdated(walletOWN, _wallet);
		walletOWN = _wallet; 
	}
	
	/**
	 * @dev Update the operator address
	 * @param _operator new operator address
	 */
	function updateOperator( address _operator ) 
		external 
		onlyOwner 
	{ 
		require(_operator != address(0)); 
		require(_operator != operator); 
		
		emit OperatorUpdated(operator, _operator);
		operator = _operator; 
	}
	
	/**
	 * @dev this function is periodically called from the owner's backend to update the exchange rate from €uro to Ethereum
	 * @param _rate new rate
	 */
	function updateRate( uint256 _rate ) 
		external 
		whenNotPaused 
		onlyOperator
	{ 
		require(_rate  > 0); 
		
		emit RateUpdated(rate, _rate); 
		rate = _rate; 
	}
}
