const Vault = artifacts.require("Vault");

const assert = require ('assert');

const utils = require("./helpers/utils");
//use default BigNumber

var expect = require('chai').expect;

contract("Vault", (accounts) => {
  let contractInstance;
  beforeEach(async () => {
      //These addresses are for MainNet
      const _tokenDAI =  "0x6B175474E89094C44Da98b954EedeAC495271d0F";
      const _CRVaddress = "0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490";
      const _curve3Pool = "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7";
      const _uniRouter = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
      const _curveFi_LPGauge = "0xFD4D8a17df4C27c1dD245d153ccf4499e806C87D";

      contractInstance = await Vault.new(_tokenDAI,_CRVaddress,_curve3Pool,_uniRouter, _curveFi_LPGauge);
  });

	it('Deploys the Contract', () => {
		assert.ok(contractInstance.address);
	});


  xit('Add Liquidity', async() => {
    const amount = 1;
    const result = await contractInstance.deposit(amount);

    const transferEvent_args = result.logs[0].args;
    const depositEvent_args = result.logs[1].args;

    const from = transferEvent_args[0];
    const to = transferEvent_args[1];
    const value = transferEvent_args[2];

    const address0 = "0x0000000000000000000000000000000000000000";

    // Check Transfer event
    assert.equal (value.toString(), amount.toString(), 'Deposited amount incorrect');
    assert.equal (from, address0 , 'Sender not correct');
    assert.equal (to, accounts[0] , 'Sender not correct');

    //Check Deposit Event
    const sender = depositEvent_args[0];
    const lpAmount = depositEvent_args[1];
    const _amount = depositEvent_args[2];

    assert.equal (sender, accounts[0] , 'Sender not correct');
    assert.equal (lpAmount.toString(), value.toString(), 'Deposited amount incorrect');
    assert.equal (_amount.toString(), amount.toString(), 'Deposited amount incorrect');

	});

  //To be completed...



})
