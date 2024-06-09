// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

// Note: To know the signature of a function if you only know its HEX value (like Metamask shows), use https://openchain.xyz/signatures

// To run this script: 
// forge script script/Interactions.s.sol:CreateSubscription

contract CreateSubscription is Script {
    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() internal returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , ) = helperConfig
            .activeNetworkConfig();
        return createSubscription(vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator
    ) public returns (uint64) {
        console.log("Creating subscription on ChainId: ", block.chainid);
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subId is: ", subId);
        console.log("Please update subscriptionId in HelperConfig");
        return subId;
    }
}

// To run this script: 
// forge script script/Interactions.s.sol:FundSubscription --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast

contract FundSubscription is Script {
    uint96 internal constant FUND_AMOUNT = 3 ether; // Since we are using LINK token, we are going to fund with 3 LINK

    function run() external {
        return fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() internal {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            address link
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subscriptionId, link);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subscriptionId,
        address link
    ) public {
        console.log(
            "Funding subscription %s on ChainId: %s ",
            subscriptionId,
            block.chainid
        );
        console.log("Using VRF Coordinator: ", vrfCoordinator);
        if (block.chainid == 31337) {
            // We are on an Anvil network
            vm.startBroadcast();
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
        console.log("Funded subscription on ChainId: ", block.chainid);
    }
}
