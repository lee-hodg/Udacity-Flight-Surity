
var Test = require('../config/testConfig.js');

contract('Flight Surety Tests', async (accounts) => {

  let config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address, {from: config.owner});
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    console.log('nada');
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, {from: config.owner});
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false, {from: config.owner});

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) can register an Airline using registerAirline() if is funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    const val = web3.utils.toBN(web3.utils.toWei("0.1", "ether"));

    console.log(`fund ${config.firstAirline} from ${config.firstAirline}`);
    try{
        await config.flightSuretyData.fund(config.firstAirline, {value: val, from: config.firstAirline});
        console.log(`Try to register new airline ${newAirline}`);
        await config.flightSuretyData.registerAirline(newAirline, "Airline 1", {from: config.firstAirline});
    }catch(e){
        console.log(e);
    }
    
    
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, true, "Airline should be able to register another airline if has funding");

  });
 
  it('(airline) cannot register an Airline using registerAirline() if over 4 airlines and not 50% vote', async () => {
    
    // ARRANGE
    let newAirline3 = accounts[3];
    let newAirline4 = accounts[4];
    let newAirline5 = accounts[5];
    let newAirline6 = accounts[6];

    // ACT
    const val = web3.utils.toBN(web3.utils.toWei("0.1", "ether"));

    try{
        // First airline registers another 2 without issue (we have itself, the 1 from previous test, and these 2 more making 4)
        // Each of them gets funded
        await config.flightSuretyData.registerAirline(newAirline3, "Airline 3", {from: config.firstAirline});
        await config.flightSuretyData.fund(newAirline3, {value: val, from: newAirline3});

        await config.flightSuretyData.registerAirline(newAirline4, "Airline 4", {from: config.firstAirline});
        await config.flightSuretyData.fund(newAirline4, {value: val, from: newAirline4});

    }catch(e){
        console.log(e);
    }
    
    // First airline cannot alone do regiseration after 4 in total
    await config.flightSuretyData.registerAirline(newAirline5, "Airline 5", {from: config.firstAirline});


    let result = await config.flightSuretyData.isAirline.call(newAirline5); 
    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline after first few");

    try{
        await config.flightSuretyData.registerAirline(newAirline5, "Airline 5", {from: newAirline3});
        console.log(`voted 1 more times...`)
    }catch(e){
        console.log(e);
    }

    let result2 = await config.flightSuretyData.isAirline.call(newAirline5); 
    // ASSERT
    assert.equal(result2, true, "Airline should be able to vote to register");



  });

});
