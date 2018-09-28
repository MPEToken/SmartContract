pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";

contract MPEToken is StandardToken
{
	string  public constant name     = "Max Panel Enerlight";
	string  public constant symbol   = "MP";
	uint256 public constant decimals = 18;

	constructor(uint256 _cap) public 
	{
		totalSupply_         = _cap;
		balances[msg.sender] = _cap;
	}
}
