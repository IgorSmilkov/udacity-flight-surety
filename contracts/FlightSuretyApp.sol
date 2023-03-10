pragma solidity ^0.8.17;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract


    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }

    mapping(bytes32 => Flight) private flights;

    FlightSuretyData private dataContract;

    mapping(address => address[]) private airlineVotes;

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() {
        // Modify to call data contract's status
        require(isOperational(), "Contract is currently not operational");
        _;
        // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor (address flightSuretyDataAddress) public {
        contractOwner = msg.sender;
        dataContract = FlightSuretyData(payable(flightSuretyDataAddress));
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns (bool) {
        return dataContract.isOperational();
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function authorizeCaller(address callerAddress) external {
        dataContract.authorizeCaller(callerAddress);
    }


    /**
     * @dev Add an airline to the registration queue
    *
    */
    function registerAirline(address airlineAddress) external payable returns (bool success, uint256 votes)  {
        require(dataContract.hasEnoughFunds(msg.sender), "Creator should have enough funds");
        require(dataContract.isAirlineRegistered(msg.sender), "Creator should be registered airlines");
        require(!dataContract.isAirlineRegistered(airlineAddress), "Airline already registered");

        if (dataContract.getFundedAirlinesCount() < 4) {
            dataContract.registerAirline(airlineAddress);
            success = true;
        } else {
            for (uint256 i = 0; i < airlineVotes[airlineAddress].length; i++) {
                require(airlineVotes[airlineAddress][i] != msg.sender, "You have already voted for this airline");
            }

            airlineVotes[airlineAddress].push(msg.sender);
            uint256 votesCount = airlineVotes[airlineAddress].length;
            if (votesCount >= dataContract.getFundedAirlinesCount() / 2) {
                dataContract.registerAirline(airlineAddress);
                success = true;
            } else {
                success = false;
            }
            votes = votesCount;
        }

        return (success, votes);
    }

    function fund(address airlineAddress) external payable {
        dataContract.fund{value : msg.value}(airlineAddress);
    }

    function getFundedAmount(address airlineAddress) public view returns(uint256) {
        return dataContract.getFundedAmount(airlineAddress);
    }

    function buy(address airlineAddress, string memory flightNumber) external payable requireIsOperational
    {
        require(msg.value <= 1 ether, "Insurance amount cannot be more than 1 ether.");
        bytes32 flightKey = dataContract.getFlightKey(airlineAddress, flightNumber);
        require(flights[flightKey].isRegistered, "Flight does not exist");
        require(!dataContract.hasInsuranceForFlight(airlineAddress, flightNumber), "You already have insurance");

        dataContract.buy{value : msg.value}(airlineAddress, flightNumber);
    }

    function pay(address airlineAddress, string memory flightNumber) external requireIsOperational {
        bytes32 flightKey = dataContract.getFlightKey(airlineAddress, flightNumber);
        require(flights[flightKey].isRegistered, "Flight does not exist");
        require(flights[flightKey].statusCode != STATUS_CODE_UNKNOWN, "Operation cannot be performed because the status is UNKNOWN");
        require(flights[flightKey].statusCode != STATUS_CODE_ON_TIME, "Operation cannot be performed because the status is ON TIME");

        dataContract.pay(airlineAddress, flightNumber, 50);
    }


    /**
     * @dev Register a future flight for insuring.
    *
    */
    function registerFlight(address airlineAddress, string memory flightNumber) external requireIsOperational {

        require(dataContract.hasEnoughFunds(airlineAddress), "Not enough funds");
        bytes32 flightKey = dataContract.getFlightKey(airlineAddress, flightNumber);
        require(!flights[flightKey].isRegistered, "FlightNumber is already registered.");

        flights[flightKey] = Flight({
        isRegistered : true,
        statusCode : STATUS_CODE_UNKNOWN,
        updatedTimestamp : block.timestamp,
        airline : airlineAddress
        });
    }

    function isFlightRegistered(address airlineAddress, string memory flightNumber) external view requireIsOperational returns (bool)
    {
        return flights[dataContract.getFlightKey(airlineAddress, flightNumber)].isRegistered;
    }

    /**
     * @dev Called after oracle has updated flight status
    *
    */

    function getFlightStatus(address airline, string memory flight) external view returns(uint8) {
        bytes32 flightKey = dataContract.getFlightKey(airline, flight);
        require(flights[flightKey].isRegistered, "Flight is not registered.");

        return flights[flightKey].statusCode;
    }

    function processFlightStatus(address airline, string memory flight, uint8 statusCode) internal {
        bytes32 flightKey = dataContract.getFlightKey(airline, flight);
        require(flights[flightKey].airline == airline, "No such airline");

        flights[flightKey].statusCode = statusCode;
        flights[flightKey].updatedTimestamp = block.timestamp;
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(address airline, string memory flight) external {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight));

        oracleResponses[key].requester = msg.sender;
        oracleResponses[key].isOpen = true;

        emit OracleRequest(index, airline, flight);
    }


    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 2;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint8 status);

    event OracleReport(address airline, string flight, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight);


    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
        isRegistered : true,
        indexes : indexes
        });
    }

    function getMyIndexes() view external returns (uint8[3] memory) {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(uint8 index, address airline, string memory flight, uint8 statusCode) external {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, statusCode);

        }
    }


    function getFlightKey(address airline, string memory flight) pure internal returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns (uint8[3] memory) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8){
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;
            // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    // endregion

}
