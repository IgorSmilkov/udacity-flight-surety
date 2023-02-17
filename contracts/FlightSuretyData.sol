pragma solidity ^0.8.17;

import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    uint256 private constant MIN_FUNDING =  10 ether;
    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping(address => bool) authorizedCallers;

    struct Airline {
        bool isRegistered;
        uint256 fundedAmount;
    }

    mapping(address => Airline) public airlines;
    address[] private airlineAddresses;
    mapping(bytes32 => uint256) private insurances;
    uint256 public numOfAirlines = 0;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor (address firstAirline) public  {
        contractOwner = msg.sender;
        _registerAirline(firstAirline);
    }

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
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsAuthorized() {
        require(authorizedCallers[msg.sender]==true, "Caller is not authorized");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() public view returns(bool) {
        return operational;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus (bool mode) external requireContractOwner  {
        operational = mode;
    }

    function authorizeCaller(address callerAddress) external requireContractOwner {
        authorizedCallers[callerAddress] = true;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline (address airlineAddress) external requireIsOperational requireIsAuthorized
    {
        _registerAirline(airlineAddress);
    }

    function _registerAirline(address airlineAddress) internal  {
        require(!airlines[airlineAddress].isRegistered, "Airline is already registered");
        airlines[airlineAddress].isRegistered = true;
        airlines[airlineAddress].fundedAmount = 0 ether;
        airlineAddresses.push(airlineAddress);
    }

    function getFundedAirlinesCount() public view returns(uint256) {
        uint256 numOfAirlines = 0;
        for (uint256 i = 0; i < airlineAddresses.length; i++) {
            if (airlines[airlineAddresses[i]].fundedAmount >= MIN_FUNDING) {
                numOfAirlines++;
            }
        }
        return numOfAirlines;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */
    function buy (address airlineAddress, string memory flightNumber) external payable requireIsOperational
    {
        require(msg.value > 0 ether, "Not enough ether sent");
        bytes32 insuranceKey=getInsuranceKey(tx.origin, airlineAddress, flightNumber);
        require(insurances[insuranceKey] == 0, "Already bought insurance for this flight");
        insurances[insuranceKey] = msg.value;
        payable(contractOwner).transfer(msg.value);
    }

    function hasInsuranceForFlight(address airlineAddress, string memory flightNumber) public view returns (bool) {
        bytes32 insuranceKey=getInsuranceKey(tx.origin, airlineAddress, flightNumber);
        return insurances[insuranceKey]!=0;
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay (address airlineAddress, string memory flightNumber, uint256 percentage) external  requireIsOperational requireIsAuthorized {
        bytes32 insuranceKey=getInsuranceKey(tx.origin, airlineAddress, flightNumber);
        require(insurances[insuranceKey] != 0 ether, "No funds for paying");

        uint256 amount = insurances[insuranceKey];
        uint256 calculatedAmount =  amount.mul(1 + percentage.div(100));
        delete insurances[insuranceKey];

        payable(tx.origin).transfer(calculatedAmount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund (address airlineAddress) public payable requireIsOperational {
        require(airlines[airlineAddress].isRegistered, "Airline not registered");
        airlines[airlineAddress].fundedAmount = airlines[airlineAddress].fundedAmount.add(msg.value);
        payable(contractOwner).transfer(msg.value);
    }

    function getFlightKey (address airline, string memory flight) external view returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flight));
    }

    function getInsuranceKey(address passengerAddress, address airline, string memory flight) pure internal returns(bytes32) {
        return keccak256(abi.encodePacked(passengerAddress, airline, flight));
    }

    function hasEnoughFunds(address airlineAddress) external view returns (bool) {
        return airlines[airlineAddress].fundedAmount >= MIN_FUNDING;
    }

    function isAirlineRegistered(address airline) public view returns(bool) {
        return airlines[airline].isRegistered;
    }

    function getFundedAmount(address airline) public view returns(uint256) {
        return airlines[airline].fundedAmount;
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    fallback() external payable {
        fund(msg.sender);
    }




}

