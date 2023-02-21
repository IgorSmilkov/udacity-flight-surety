const express = require('express');
const FlightSuretyApp = require('../../build/contracts/FlightSuretyApp.json');
const Config = require('./config.json');
const Web3 = require('web3');

const app = express();
app.listen(3000);

app.get('/api', (req, res) => {
 res.send({
  message: 'An API for use with your Dapp!'
 });
});

const initialize = async () => {
 const config = Config['localhost'];
 const web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
 const accounts = await web3.eth.getAccounts();
 web3.eth.defaultAccount = accounts[0];
 const flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

 const oracles = [];
 const oraclesCount = 10;
 const registrationFee = await flightSuretyApp.methods.REGISTRATION_FEE().call();
 for (let i = 0; i < oraclesCount; i++) {
  const account = accounts[i];
  await flightSuretyApp.methods.registerOracle().send({from: account, value: registrationFee, gas: 3000000});
  const indexes = await flightSuretyApp.methods.getMyIndexes().call({from: account});
  oracles.push({
   account,
   indexes
  });
  console.log(`Registered oracle ${account} ${indexes}`);
 }

 const STATUS_CODES = {
  UNKNOWN: 0,
  ON_TIME: 10,
  LATE_AIRLINE: 20,
  LATE_WEATHER: 30,
  LATE_TECHNICAL: 40,
  LATE_OTHER: 50,
 };

 flightSuretyApp.events.OracleRequest({fromBlock: 0}, async (error, event) => {
  if (error) {
   console.log(error);
  }

  const airline = event.returnValues.airline;
  const flightNumber = event.returnValues.flight;
  const index = event.returnValues.index;
  console.log(`Oracle request for flight ${flightNumber} with index ${index}`);

  const statusCode = Object.values(STATUS_CODES)[Math.floor(Math.random() * 6)];
  oracles.forEach(async (oracle) => {
   if (oracle.indexes.includes(index)) {
    try {
     await flightSuretyApp.methods.submitOracleResponse(
        index,
        airline,
        flightNumber,
        statusCode,
     ).send({from: oracle.account, gas: 2000000});
    } catch (e) {
     console.log(e);
    }
    console.log(`Oracle ${oracle.account} responded with status code ${statusCode}`);
   }
  });
 });

 flightSuretyApp.events.OracleReport({fromBlock: 0}, (error, event) => {
  if (error) {
   console.log(error);
  }
  const airline = event.returnValues.airline;
  const flightNumber = event.returnValues.flight;
  const status = event.returnValues.status;

  console.log(`Received response for flight airline:${airline}, flight ${flightNumber} status Code: ${status}`);
 });

 flightSuretyApp.events.FlightStatusInfo({
  fromBlock: 0
 }, function (error, event) {
  if (error) {
   console.log(error);
  }
  const airline = event.returnValues.airline;
  const flightNumber = event.returnValues.flight;
  const status = event.returnValues.status;

  console.log(`Final status for flight airline:${airline}, flight ${flightNumber} Status Code: ${status}`);
 });
}

initialize().then(
   result => {
   },
   error => {
    console.log(error);
   }
)
