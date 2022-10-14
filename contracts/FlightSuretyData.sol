// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


contract FlightSuretyData {

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    uint256 public constant MIN_FUNDING_FEE = 0.1 ether;

    // Airline
    struct Airline {
        string name;
        uint256 funds;  
        bool isRegistered;
        bool isFunded; // Did they submit their stake?
    }
    // Since mappings don't have a length, count airlines
    uint256 registeredAirlineCount = 0;
    mapping(address => Airline) private airlines;

    // To check that only App contract can call in!
    mapping(address => uint256) authorizedCallers;                      

    // Threshold below which all we need is a single airline to add a new airline                         
    uint256 constant AIRLINE_THRESHOLD = 4;                                            
    // Record which airlines that voted
    // the key is the address we are voting to add and the value is an array of airline addresses who voted to add this airline
    mapping(address => address[]) airlineVotes;           

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event AirlineFunded(address airline, uint256 amount, bool isRegistered, bool isFunded);
    event FundsReceived(address receiver, uint256 amount, address sender);
    event TestEvent(uint256 x);
    event AirlineRegistered(address airlineAddress, string name, uint256 funds,  bool isRegistered, bool isFunded);
    event AchievedMultiPartyConsensus(address newAirlineAddress, uint256 votesCount, uint airlinesCount);
    event NotYetAchievedMultiPartyConsensus(address newAirlineAddress, uint256 votesCount, uint airlinesCount);


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    *      and we register the first airline...
    *address airlineAddress, string memory airlineName)
    */
    constructor (address airlineAddress)
    {
        contractOwner = msg.sender;
        // airline is the first authorized caller
        authorizedCallers[contractOwner] = 1;
        authorizedCallers[airlineAddress] = 1;
        registeredAirlineCount = 1;
        // name, funds, isRegistered, isFunded
        airlines[airlineAddress] = Airline("EasyJet", 0, true, false);
        emit AirlineRegistered(airlineAddress, "EasyJet", 0, true, false);

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
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * @dev Modifier checking that only the App contract can call in! --> For every externally callable function!
    */
    modifier isCallerAuthorized()
    {
        require(authorizedCallers[msg.sender] == 1, "Caller is not authorized!");
        _;
    }

    /** 
    * @dev Modifier that implements multi-party consensus to execute a specific function
    */
    modifier requireMultiPartyConsensus(address caller, address newAirlineAddress)
    {
        // You have to be an authorized airline to even have a vote
        // you have to also be a registered and funded airline
        require(authorizedCallers[caller] == 1, "[multipartycon] Caller is not authorized!");
        require(airlines[caller].isRegistered, "[multipartycon] Airline is not registered!");
        require(airlines[caller].isFunded, "[multipartycon] Airline is not funded!");

        
        if (registeredAirlineCount < AIRLINE_THRESHOLD){
            // If less than 4 airlines registered all we need is 1 vote from any authorized airline
            // no multi-party consensus required
            emit AchievedMultiPartyConsensus(newAirlineAddress, 1, registeredAirlineCount);
            _;
        }else{
            // Check if this Airline already made its vote to avoid them voting twice
            bool isDuplicate = false;
            address[] memory currentVotes = airlineVotes[newAirlineAddress];
            for(uint c=0; c< currentVotes.length; c++) {
                if (currentVotes[c] == caller) {
                    isDuplicate = true;
                    break;
                    }
            }
            require(!isDuplicate, "Airline has already voted.");

            // If not then add the vote to the array of votes for this newairline
            airlineVotes[newAirlineAddress].push(caller);


            // Check if it was a sufficient number of votes to achieve consensus
            uint256 numberOfVotes = airlineVotes[newAirlineAddress].length;
            uint256 unvotedCount = registeredAirlineCount - numberOfVotes;
            if(numberOfVotes >= unvotedCount){
                emit AchievedMultiPartyConsensus(newAirlineAddress, numberOfVotes, registeredAirlineCount);
                _;
            }else{
                emit NotYetAchievedMultiPartyConsensus(newAirlineAddress, numberOfVotes, registeredAirlineCount);
            }
        }

    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/
    function kill() public requireContractOwner() {
        if (msg.sender == contractOwner) {
            selfdestruct(payable(msg.sender));
        }
    }

    function authorizeCaller(address _caller) public isCallerAuthorized {
        // only other authorized callers (airlines) can add other authorized callers
        authorizedCallers[_caller] = 1;
    }

    function isAuthorized(address _caller) public view returns(uint256) {
        return authorizedCallers[_caller];
    }

    function deAuthorizeCaller(address _caller) public isCallerAuthorized {
        authorizedCallers[_caller] = 0;
    }
    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (
                                address airlineAddress,
                                string calldata name  
                            )
                            external
                            requireIsOperational
                            requireMultiPartyConsensus(msg.sender, airlineAddress)
    {
        require(!airlines[airlineAddress].isRegistered, "Airline is already registered!");

        // Data structure for Airlines?
        airlines[airlineAddress] = Airline(name, 0, true, false);
        authorizedCallers[airlineAddress] = 1;
        registeredAirlineCount++;

    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (                             
                            )
                            external
                            payable
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund(address airlineAddress)
        external
        payable
        requireIsOperational
    {
        require(msg.value >= MIN_FUNDING_FEE, "[fund] Inadaquate funds sent");
        require(airlines[airlineAddress].isRegistered, "[fund] Airline is not registered!");

        // Transfer to the contract those funds
        //payable(contractOwner).transfer(msg.value);
        payable(address(this)).transfer(msg.value);

        // Add to the Airline's funds
        uint256 currentFunds = airlines[airlineAddress].funds;
        airlines[airlineAddress].funds = msg.value + currentFunds;
        airlines[airlineAddress].isFunded = true;
        airlines[airlineAddress].isRegistered = true;

        emit AirlineFunded(airlineAddress,  airlines[airlineAddress].funds, airlines[airlineAddress].isRegistered, airlines[airlineAddress].isFunded);

    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Checking if registered airline is registered
    */    
    function isAirline (address addressAirline) external view requireIsOperational returns(bool) {
        require(addressAirline != address(0), "0x0 address not allowed!");
        if(airlines[addressAirline].isRegistered){
            return true;
        } else{
            return false;
        }
    } 

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    // fallback() 
    //                         external 
    //                         payable 
    // {
    //     emit FundsAdded(address(this), msg.value);
    // }

    receive() external payable {
        emit FundsReceived(address(this), msg.value, msg.sender);
    }

}

