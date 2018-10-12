const MPEConfig    = require('../MPEConfig.js');
const MPEToken     = artifacts.require('./MPEToken.sol');
const MPECrowdsale = artifacts.require('./MPECrowdsale.sol');

module.exports = function(deployer, network, accounts) 
{
	const rate = new web3.BigNumber(166.442263873 * 10**18);

	var icoStart;
	var icoStage2;
	var icoStage3;
	var icoEnd;
	
	if( network == 'development' )
	{
		icoStart  = Math.floor(Date.now() / 1000) + 15;
		icoStage2 = icoStart + 600;
		icoStage3 = icoStage2 + 600;
		icoEnd    = icoStage3 + 600;
	}
	
	if( network == 'ropsten' )
	{
		icoStart  = Math.floor(Date.now() / 1000) + 120;
		icoStage2 = 1540944000;  // 2018-10-31 12:00am (UTC)
		icoStage3 = 1543190400;  // 2018-11-26 12:00am (UTC)
		icoEnd    = 1551139200;  // 2019-02-26 12:00am (UTC)
	}
	
	if( network == 'mainnet' )
	{
		icoStart  = 1539302400;  // 2018-10-12 12:00am (UTC)
		icoStage2 = 1540944000;  // 2018-10-31 12:00am (UTC)
		icoStage3 = 1543190400;  // 2018-11-26 12:00am (UTC)
		icoEnd    = 1551139200;  // 2019-02-26 12:00am (UTC)
	}
	
	const operator  = MPEConfig.networks[network].operator.address;
	const owner     = MPEConfig.networks[network].owner.address;
	const adv1      = MPEConfig.networks[network].adv1.address;
	const adv2      = MPEConfig.networks[network].adv2.address;
	const adv3      = MPEConfig.networks[network].adv3.address;

	return deployer.deploy( MPECrowdsale, rate, icoStart, icoStage2, icoStage3, icoEnd, operator, owner, adv1, adv2, adv3 );
	
}
