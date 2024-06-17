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
        uint256 deployerKey;
    }

    uint256 public constant DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig public activeNetworkConfig;

    constructor() {
        // 11155111 -> Sepolia chain id
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30, // seconds
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625, // VRF Coordinator -> https://docs.chain.link/vrf/v2-5/supported-networks/#sepolia-testnet
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // 100 gwei Key Hash -> https://docs.chain.link/vrf/v2-5/supported-networks/#sepolia-testnet
                subscriptionId: 0, // The subscription ID given by Chainlink does not fit in uint64. Investigate a workaround
                callbackGasLimit: 500000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789, // LINK token contract address -> https://docs.chain.link/resources/link-token-contracts
                deployerKey: vm.envUint("ZERO_PRIVATE_KEY")
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        } else {
            // As VRFCoordinatorV2Mock works with LINK token, we are going to simulate LINK token with ether
            uint96 baseFee = 0.25 ether; // 0.25 LINK
            uint96 getPriceLink = 1e9; // 1 gwei LINK

            vm.startBroadcast(DEFAULT_ANVIL_KEY);
            VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
                baseFee,
                getPriceLink
            );
            LinkToken link = new LinkToken();
            vm.stopBroadcast();

            return
                NetworkConfig({
                    entranceFee: 0.01 ether,
                    interval: 30, // seconds
                    vrfCoordinator: address(vrfCoordinatorMock),
                    gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // 100 gwei Key Hash -> https://docs.chain.link/vrf/v2-5/supported-networks/#sepolia-testnet
                    subscriptionId: 0, // TODO: Our script will add this
                    callbackGasLimit: 500000,
                    link: address(link),
                    deployerKey: DEFAULT_ANVIL_KEY
                });
        }
    }
}
