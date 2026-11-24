// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {RecordRegistry} from "../src/RecordRegistry.sol";
import {ConsentManager} from "../src/ConsentManager.sol";

/// @title DeployCareConsent
/// @notice Deploys RecordRegistry and ConsentManager to Anvil or an EVM development network.
contract DeployCareConsent is Script {
    /// @dev Anvil default account #1 used as the local gateway signer when GATEWAY_ADDRESS is not set.
    address internal constant DEFAULT_ANVIL_GATEWAY = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    function run() external returns (RecordRegistry registry, ConsentManager consentManager) {
        address gatewayAddress = vm.envOr("GATEWAY_ADDRESS", DEFAULT_ANVIL_GATEWAY);

        vm.startBroadcast();
        registry = new RecordRegistry();
        consentManager = new ConsentManager(gatewayAddress);
        vm.stopBroadcast();

        console2.log("RecordRegistry deployed at:", address(registry));
        console2.log("ConsentManager deployed at:", address(consentManager));
        console2.log("Authorized gateway signer:", gatewayAddress);
    }
}
