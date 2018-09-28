const MPEConfig    = require('../MPEConfig.js');
const MPEToken      = artifacts.require('./MPEToken.sol');
const MPECrowdsale = artifacts.require('./MPECrowdsale.sol');

module.exports = function(deployer, network, accounts) 
{
	const rate      = new web3.BigNumber(10000 * 10**18);

	const icoStart  = Math.floor(Date.now() / 1000) + 15;
	const icoStage2 = icoStart + 60;
	const icoStage3 = icoStage2 + 60;
	const icoEnd    = icoStage3 + 60;

//	const icoStart  = 1538352000;
//	const icoStage2 = 1539648000;
//	const icoStage3 = 1542672000;
//	const icoEnd    = 1546300800;

//	const w1        = MPEConfig.networks[network].admin.address;
//	const w2        = MPEConfig.networks[network].admin.address;
//	const w3        = MPEConfig.networks[network].admin.address;
//	const w4        = MPEConfig.networks[network].admin.address;
//	const operator  = MPEConfig.networks[network].operator.address;

	const w1        = accounts[1]; // ADV1
	const w2        = accounts[2]; // ADV2
	const w3        = accounts[3]; // ADV3
	const w4        = accounts[4]; // OWN
	const operator  = accounts[5]; // OPER

	return deployer.deploy( MPECrowdsale, rate, icoStart, icoStage2, icoStage3, icoEnd, w1, w2, w3, w4, operator );
}
