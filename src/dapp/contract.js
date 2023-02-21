import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor() {

    }

    async initialize(network) {
        let config = Config[network];
        await this.initializeWeb3(config);
        await this.initializeContracts(config);
    }

    async initializeWeb3(config) {
        let web3Provider;
        if (window.ethereum) {
            web3Provider = window.ethereum;
            try {
                await window.ethereum.enable();
            } catch (error) {
                console.error("User denied account access")
            }
        } else if (window.web3) {
            web3Provider = window.web3.currentProvider;
        } else {
            web3Provider = new Web3.providers.HttpProvider(config.url);
        }
        this.web3 = new Web3(web3Provider);
    }

    async initializeContracts(config) {
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
    }

    async authorizeCaller(airlineAddress) {
        let account = await this.getCurrentAccount();
        await this.flightSuretyApp.methods.authorizeCaller(airlineAddress).send({ from: account});
    }

    async registerAirline(airlineAddress) {
        let account = await this.getCurrentAccount();
        await this.flightSuretyApp.methods.registerAirline(airlineAddress).send({ from: account});
    }

    async fundAirline(airlineAddress, amount) {
        let account = await this.getCurrentAccount();
        let amountWei = this.web3.utils.toWei(amount, 'ether');
        await this.flightSuretyApp.methods.fund(airlineAddress).send({ from: account, value: amountWei });
    }

    async getFundedAmount() {
        let account = await this.getCurrentAccount();
        let amount= await this.flightSuretyApp.methods.getFundedAmount(account).call();
        console.log(`Funded amount for ${account} is ${amount}`)
    }

    async registerFlight(flightAirlineAddress, flightNumber) {
        let account = await this.getCurrentAccount();
        await this.flightSuretyApp.methods.registerFlight(flightAirlineAddress,flightNumber).send({ from: account });
    }

    async getFlightStatus(flightAirlineAddress, flightNumber) {
        let account = await this.getCurrentAccount();
        let result = await this.flightSuretyApp.methods.getFlightStatus(flightAirlineAddress, flightNumber).call({ from: account});
        console.log("Flight Status Code: ", result);

        switch (result) {
            case "10":
                return "On time";
            case "20":
                return "Late airline";
            case "30":
                return "Late weather";
            case "40":
                return "Late technical";
            case "50":
                return "Late other";
            default:
                return "Unknown";
        }
    }

    async fetchFlightStatus(flightAirlineAddress, flightNumber) {
        let account = await this.getCurrentAccount();
        await this.flightSuretyApp.methods.fetchFlightStatus(flightAirlineAddress,flightNumber).send({ from: account });
    }

    async buyInsurance(airlineAddress, flightNumber, amount) {
        let account = await this.getCurrentAccount();
        let amountWei = this.web3.utils.toWei(amount, 'ether');
        await this.flightSuretyApp.methods.buy(airlineAddress,flightNumber).send({ from: account, value: amountWei });
    }

    async getPaid(flightAirlineAddress, number) {
        let account = await this.getCurrentAccount();
        await this.flightSuretyApp.methods.pay(flightAirlineAddress,number).send({ from: account });
    }

    async getCurrentAccount() {
        try {
            let accounts = await this.web3.eth.getAccounts();
            return accounts[0];
        } catch (error) {
            console.log(error);
        }
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }
}
