// Solidity docs recommendations about Code Style:

// Layout of Contract
// ------------------
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// ------------------
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title A sample Raffle contract
 * @author Andrés de la Grana
 * @notice This contract if for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughETHSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpened();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    /** Type Declarations */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    /**
     * @dev Duration of the lottery in seconds
     */
    uint256 private immutable i_interval;
    uint256 private immutable i_entranceFee;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint64 private immutable i_subscriptionId;
    address payable[] private s_players;
    address private s_recentWinner;
    uint256 private s_lastTimeStamp;
    RaffleState private s_raffleState;

    /** Events */

    event RaffleEntered(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator, // This value depends on the chain
        bytes32 gasLane, // This value depends on the chain
        uint64 subscriptionId, // Chainlink subscription Id for VRF
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        s_raffleState = RaffleState.OPEN;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() external payable {
        // Instead of doing a require, we can use a custom error which is more gas efficient.
        // NOT THIS -> require(msg.value >= i_entranceFee, "Raffle: Not enough ETH sent!");
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpened();
        }
        // We need the payable cast to make the address able to be payed ETH
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    // When is the winner supposed to be picked?
    /**
     * @dev This the function that the Chainlink Automation nodes call to see if it's time to perform an upkeep.abi
     * The following needs to be true for this to return true:
     * 1. The time interval has passed between raffle runs
     * 2. The raffle is in the OPEN state
     * 3. The contract has ETH (aka players)
     * 4. (Implicit) The suscription is funded with LINK
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "0x0");
    }

    // We want this function to
    // 1. Get a random number
    // 2. User the random number to pick a player
    // 3. Be automatically called
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    // Design pattern CEI: Checks, Effects, Interactions
    // This protect us against re-entrancy attacks
    function fulfillRandomWords(
        uint256 /* _requestId */, 
        // Syntax clarification: 
        // - uint256 /* _requestId */ is a required parameter for the function signature, but it's not used within the function body.
        // - The comment syntax /* _requestId */ serves as a placeholder to indicate that this parameter is intentionally not used.
        uint256[] memory _randomWords
    ) internal override {
        // Checks

        // Effects -> Changes to our contract
        uint256 indexOfRandomWinner = _randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfRandomWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0); // Clear the array
        s_lastTimeStamp = block.timestamp; // Start the clock over
        emit PickedWinner(winner);

        // Interactions -> With another contract
        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /** Getter functions */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getPlayersCount() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}

// Note: Smart contracts can emit events. In this case, when a player enters the raffle.
// Events are very useful because they can be listened by the frontend. They are "logged" in the blockchain.
// Smart contracts can't access blockchain logs
// If you see in etherscan in the Tx logs, you'll see the logs of the events emitted by the contract.
// Video about Events -> https://www.youtube.com/watch?v=69Yl2FEtbjc&list=PL2-Nvp2Kn0FPH2xU3IbKrrkae-VVXs1vk&index=110
