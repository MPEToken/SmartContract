require('dotenv').config();

const MPECrowdsale = artifacts.require("MPECrowdsale");

const percDiff = 3;

web3.eth.getTransactionReceiptMined = async function getTransactionReceiptMined(txHash, interval) 
{
    const self = this;
    const transactionReceiptAsync = function(resolve, reject) {
        self.getTransactionReceipt(txHash, (error, receipt) => {
            if (error) {
                reject(error);
            } else if (receipt == null) {
                setTimeout(
                    () => transactionReceiptAsync(resolve, reject),
                    interval ? interval : 500);
            } else {
                resolve(receipt);
            }
        });
    };

    if (Array.isArray(txHash)) {
        return Promise.all(txHash.map(
            oneTxHash => self.getTransactionReceiptMined(oneTxHash, interval)));
    } else if (typeof txHash === "string") {
        return new Promise(transactionReceiptAsync);
    } else {
        throw new Error("Invalid Type: " + txHash);
    }
};

module.exports = async function(callback) 
{
	argv = process.argv.slice(4);
	if( argv.length < 1 )
	{
		callback('invalid argument');
		process.exit();
	} else {
		if( argv[0] == '--network' )
		{
			network = argv[1];
			argv = argv.slice(2);
		} else {
			network = 'development';
		}
	}

	if( argv.length != 1 )
	{
		callback('invalid argument');
		process.exit();
	}

	crw = await MPECrowdsale.deployed();
	
	console.log( "Crowdsale:   " + crw.address );

	price = parseFloat( argv[0] );
	
	console.log( "\nPrice    : " + price );
	
	if( isNaN(price) )
	{
		callback('unable to parse price value: '+argv[0] );
		process.exit();
	} else {
		price -= price / 100 * percDiff;
		console.log( "Adj Price: " + price + "\t(price - " + percDiff + "%)");
	}
	
	oldPrice = web3.fromWei( new web3.BigNumber( (await crw.rate.call()) ), 'ether' );
	
	console.log( "Old Price: " + oldPrice );

	runUpd = false;
	
	if( oldPrice == price )
	{
		console.log( "\nPrice isn't changed... aborting" );
	} else {
		if( price > oldPrice )
		{
			diff = 100 / oldPrice * (price-oldPrice);
			
			if( diff > 1.5 )
				runUpd = true;
			
		} else {
			diff = 100 / price * (oldPrice-price);
			
			if( diff > 1 )
				runUpd = true;
		}
		
		console.log( "diff     : " + diff + " %");
		
	}
	
	runUpd = true;
	if( runUpd )
	{
		console.log( "\nUpdating Price..." );
		
		tx = await crw.updateRate.sendTransaction( price * 10**18 );
		console.log( "Waiting for TX " + tx + "..." );
	    
		receipt = await web3.eth.getTransactionReceiptMined( tx );
		
		console.log("receipt:");
		console.log(receipt);
	} else {
		console.log( "\nUpdate not needed." );
	}
	
	callback();
	process.exit();
}
