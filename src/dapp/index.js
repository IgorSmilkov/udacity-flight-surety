
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';

window.addEventListener('load', async () => {
    let contract = new Contract();
    await contract.initialize('localhost');

    document.getElementById('authorize-button').addEventListener('click', async () => {
        let airlineAddress = document.getElementById('authorize-airline-address').value;
        await contract.authorizeCaller(airlineAddress);
    });

    document.getElementById('fund-button').addEventListener('click', async () => {
        let airlineAddress = document.getElementById('fund-airline-address').value;
        let amount = document.getElementById('fund-airline-amount').value;
        await contract.fundAirline(airlineAddress, amount);
        await contract.getFundedAmount();
    });

    document.getElementById('register-airline-button').addEventListener('click', async () => {
        let airlineAddress = document.getElementById('register-airline-address').value;
        await contract.registerAirline(airlineAddress);
    });

    document.getElementById('register-flight-button').addEventListener('click', async () => {
        let flightAirlineAddress = document.getElementById('flight-airline-address').value;
        let flightNumber = document.getElementById('flight-number').value;
        await contract.registerFlight(flightAirlineAddress, flightNumber);
    });

    document.getElementById('get-current-status-button').addEventListener('click', async () => {
        let flightAirlineAddress = document.getElementById('flight-airline-address').value;
        let flightNumber = document.getElementById('flight-number').value;
        let flightStatus = await contract.getFlightStatus(flightAirlineAddress, flightNumber);
        document.getElementById('flight-status').value = flightStatus;
    });

    document.getElementById('request-flight-status-button').addEventListener('click', async () => {
        let flightAirlineAddress = document.getElementById('flight-airline-address').value;
        let flightNumber = document.getElementById('flight-number').value;
        await contract.fetchFlightStatus(flightAirlineAddress, flightNumber);
    });


    document.getElementById('insurance-button').addEventListener('click', async () => {
        let airlineAddress = document.getElementById('insurance-airline-address').value;
        let flightNumber = document.getElementById('insurance-flight-number').value;
        let insuranceAmount  = document.getElementById('insurance-amount').value;
        await contract.buyInsurance(airlineAddress, flightNumber,insuranceAmount);
    });

    document.getElementById('get-paid-button').addEventListener('click', async () => {
        let flightAirlineAddress = document.getElementById('late-airline-address').value;
        let flightNumber = document.getElementById('late-flight-number').value;
        await contract.getPaid(flightAirlineAddress, flightNumber);
    });
})


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}







