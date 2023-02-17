var Test = require('../config/testConfig.js');
var Web3 = require('web3');

contract('Flight Surety Tests', async (accounts) => {

   var config;
   before('setup contract', async () => {
      config = await Test.Config(accounts);
      await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
   });

   /****************************************************************************************/
   /* Operations and Settings                                                              */
   /****************************************************************************************/

   it(`(multiparty) has correct initial isOperational() value`, async function () {

      // Get operating status
      let status = await config.flightSuretyData.isOperational.call();
      assert.equal(status, true, "Incorrect initial operating status value");

   });

   it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try {
         await config.flightSuretyData.setOperatingStatus(false, {from: config.testAddresses[2]});
      } catch (e) {
         accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

   });

   it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try {
         await config.flightSuretyData.setOperatingStatus(false);
      } catch (e) {
         accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

   });

   it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try {
         await config.flightSurety.setTestingMode(true);
      } catch (e) {
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
      } catch (e) {

      }
      let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);

      // ASSERT
      assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

   });

   it('First airline should be registered on contract deploy', async () => {
      assert.equal(true, await config.flightSuretyData.isAirlineRegistered(accounts[1]), "Airline is not registered");
   });


   it('Non-funded registered airline cannot register new airline', async () => {
      // ARRANGE
      let newAirline = accounts[2];

      // ACT
      try {
         await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
      } catch (e) {

      }
      let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);

      // ASSERT
      assert.equal(false, result, "Airline should not be able to register another airline if it hasn't provided funding");

   });

   it('Funded registered airline can register new airline', async () => {
// ARRANGE
      let newAirline = accounts[2];

      // ACT
      await config.flightSuretyApp.fund(config.firstAirline, {from: config.firstAirline, value:  Web3.utils.toWei('10', 'ether')})
      await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});

      let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);

      // ASSERT
      assert.equal(true, result, "Airline should be register");
   });

   it('If more that 4 airlines are registered, consensus of 50% is needed for registering new airline', async () => {
      assert.equal(1, await config.flightSuretyData.getFundedAirlinesCount(), "Number of registered and funded airlines are not 1");
      await config.flightSuretyApp.fund(accounts[2], {from: accounts[2], value:  Web3.utils.toWei('10', 'ether')})
      assert.equal(2, await config.flightSuretyData.getFundedAirlinesCount(), "Number of registered and funded airlines are not 2");
      await config.flightSuretyApp.registerAirline(accounts[3], {from: accounts[2]});
      await config.flightSuretyApp.fund(accounts[3], {from: accounts[3], value:  Web3.utils.toWei('10', 'ether')})
      assert.equal(3, await config.flightSuretyData.getFundedAirlinesCount(), "Number of registered and funded airlines are not 3");
      await config.flightSuretyApp.registerAirline(accounts[4], {from: accounts[3]});
      await config.flightSuretyApp.fund(accounts[4], {from: accounts[4], value:  Web3.utils.toWei('10', 'ether')})
      assert.equal(4, await config.flightSuretyData.getFundedAirlinesCount(), "Number of registered and funded airlines are not 4");

      //Now for the next test. we sould have 2 votes in order to register the next airline
      await config.flightSuretyApp.registerAirline(accounts[5], {from: accounts[3]});
      assert.equal(false, await config.flightSuretyData.isAirlineRegistered(accounts[5]), "Airline is registered");
      await config.flightSuretyApp.registerAirline(accounts[5], {from: accounts[2]});
      assert.equal(true, await config.flightSuretyData.isAirlineRegistered(accounts[5]), "Airline is not registered");
      assert.equal(4, await config.flightSuretyData.getFundedAirlinesCount(), "Number of registered and funded airlines are not 4");
      await config.flightSuretyApp.fund(accounts[5], {from: accounts[5], value:  Web3.utils.toWei('10', 'ether')})
      assert.equal(5, await config.flightSuretyData.getFundedAirlinesCount(), "Number of registered and funded airlines are not 5");
   });


});
