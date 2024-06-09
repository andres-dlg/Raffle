// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        // 11155111 -> Sepolia chain id
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30, // seconds
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // VRF Coordinator -> https://docs.chain.link/vrf/v2-5/supported-networks/#sepolia-testnet
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // 100 gwei Key Hash -> https://docs.chain.link/vrf/v2-5/supported-networks/#sepolia-testnet
                subscriptionId: 0, // The subscription ID given by Chainlink does not fit in uint64. Investigate a workaround
                callbackGasLimit: 500000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789 // LINK token contract address -> https://docs.chain.link/resources/link-token-contracts
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory)
    {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        } else {
            // As VRFCoordinatorV2Mock works with LINK token, we are going to simulate LINK token with ether
            uint96 baseFee = 0.25 ether; // 0.25 LINK
            uint96 getPriceLink = 1e9; // 1 gwei LINK

            vm.startBroadcast();
            VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(baseFee, getPriceLink);
            LinkToken link = new LinkToken();
            vm.stopBroadcast();

            return NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30, // seconds
                vrfCoordinator: address(vrfCoordinatorMock),
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // 100 gwei Key Hash -> https://docs.chain.link/vrf/v2-5/supported-networks/#sepolia-testnet
                subscriptionId: 0, // TODO: Our script will add this
                callbackGasLimit: 500000,
                link: address(link)
            });
        }
    }
}
