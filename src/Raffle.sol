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

import {VRFCoordinatorV2Interface} from "@chainlink/contracts@1.1.1/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

/**
 * @title A sample Raffle contract
 * @author Andrés de la Grana
 * @notice This contract if for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle {
    error Raffle__NotEnoughETHSent();

    //** State Variables */
    uint256 private constant REQUEST_CONFIRMATIONS = 3;
    uint256 private constant NUM_WORDS = 1;

    /**
     * @dev Duration of the lottery in seconds
     */
    uint256 private immutable i_interval;
    uint256 private immutable i_entranceFee;
    address private immutable i_vrfCoordinator;
    uint256 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint64 private immutable i_subscriptionId;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

    /** Events */

    event RaffleEntered(address indexed playe);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator, // This value depends on the chain
        bytes32 gasLane, // This value depends on the chain
        uint64 subscriptionId, // Chainlink subscription Id for VRF
        uint32 callbackGasLimit
    ) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = vrfCoordinator;
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() external payable {
        // Instead of doing a require, we can use a custom error which is more gas efficient.
        // NOT THIS -> require(msg.value >= i_entranceFee, "Raffle: Not enough ETH sent!");
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHSent();
        }
        // We need the payable cast to make the address able to be payed ETH
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    // We want this function to
    // 1. Get a random number
    // 2. User the random number to pick a player
    // 3. Be automatically called
    function pickWinner() external {
        if ((block.timestamp - s_lastTimeStamp) <= i_interval) {
            revert();
        }

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }

    /** Getter functions */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}

// Note: Smart contracts can emit events. In this case, when a player enters the raffle.
// Events are very useful because they can be listened by the frontend. They are "logged" in the blockchain.
// Smart contracts can't access blockchain logs
// If you see in etherscan in the Tx logs, you'll see the logs of the events emitted by the contract.
// Video about Events -> https://www.youtube.com/watch?v=69Yl2FEtbjc&list=PL2-Nvp2Kn0FPH2xU3IbKrrkae-VVXs1vk&index=110
