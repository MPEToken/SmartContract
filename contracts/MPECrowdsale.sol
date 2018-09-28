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
	
	uint256 private constant p100        = 100 * 10e18;
	uint256 private constant p10         = 10  * 10e18;
	uint256 private constant precision   = 10e6;
	
	// Setted at deploy time for debug purpose
	uint256 private ICO_START;   	// 1538352000 = 01/10/2018 @ 12:00am (UTC)
	uint256 private ICO_STAGE_2; 	// 1539648000 = 16/10/2018 @ 12:00am (UTC)
	uint256 private ICO_STAGE_3; 	// 1542672000 = 20/11/2018 @ 12:00am (UTC)
	uint256 private ICO_END;     	// 1546300800 = 01/01/2019 @ 12:00am (UTC)
	
	uint256 public constant TOKEN_CAP = 37.5  * 10e6 * 10e18; // 37,5 million MPEs total supply
	uint256 public constant CAP_10P   =  3.75 * 10e6 * 10e18; // 10% of the TOKEN_CAP
	uint256 public constant CAP_20P   =  7.5  * 10e6 * 10e18; // 20% of the TOKEN_CAP
	
	address public walletOWN;		// Address to collet the funds
	
	address public operator;		// Address of the operator of the Contract for the periodic exchange rate update
	
	uint256 public soldToken  = 0;	// Amount of token sold
	uint256 public bonusToken = 0;	// Amount of bonus token provided

	uint256 private tmpSold   = 0;	// temp variable to calculate the token sold during the purchase
	uint256 private tmpBonus  = 0;	// temp variable to calculate the bonus provided during the purchase
	
	enum stage { notStarted, stage1, stage2, stage3, closed }

	uint256 public constant tokenPrice   = 11.5 * 10e18;	// 11,5 €uro x token
	uint256 public constant stage1Bonus  = 30   * 10e18;
	uint256 public constant stage2Bonus  = 20   * 10e18;
	uint256 public constant stage3Bonus  = 10   * 10e18;
	
	//event evDebug( string msgText, uint256 msgVal);
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
	 * @param _walletADV1 Address of the 1st advisor to collet the 20% of the token at deploy time
	 * @param _walletADV2 Address of the 2st advisor to collet the 10% of the token at deploy time
	 * @param _walletADV3 Address of the 3st advisor to collet the 20% of the token at finalize time
	 * @param _walletOWN  Address to collet the funds
	 * @param _operator   Address of the operator of the Contract for the periodic exchange rate update
	 */
	constructor(
			uint256 _rate,
			uint256 _icoStart,
			uint256 _icoStage2,
			uint256 _icoStage3,
			uint256 _icoEnd,
			address _walletADV1,
			address _walletADV2,
			address _walletADV3,		
			address _walletOWN,		
			address _operator
	) 
		public
		Crowdsale(_rate, _walletOWN, ERC20( new MPEToken(TOKEN_CAP) ) )
		TimedCrowdsale(_icoStart, _icoEnd)
	{
		require(_walletADV1 != address(0));
		require(_walletADV2 != address(0));
		require(_walletADV3 != address(0));
		require(_walletOWN  != address(0));
		require(_operator   != address(0));
		
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
		// TODO - Minimum Purchase must be >= 2500 €uro
		
		//require( _weiAmount.mul(rate) >= 11.5 * 10e18 ); 
		
		tmpSold  = _weiAmount.mul( rate ).div( tokenPrice );
		tmpBonus = tmpSold.div(p100).mul( _currentBonus(_currentStage()) );

		uint256 _avail = token.balanceOf(this);
		
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
		
		return _t.add( _t.div(p100).mul( _currentBonus(_currentStage()) ) );
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
