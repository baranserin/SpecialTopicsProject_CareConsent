// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {RecordRegistry} from "../src/RecordRegistry.sol";
import {ConsentManager} from "../src/ConsentManager.sol";
import {ResearchSettlement} from "../src/ResearchSettlement.sol";

/// @title DeployCareConsent
/// @notice Deploys RecordRegistry, ConsentManager, and ResearchSettlement to Anvil or an EVM development network.
contract DeployCareConsent is Script {
    /// @dev Anvil default account #1 used as the local gateway signer when GATEWAY_ADDRESS is not set.
    address internal constant DEFAULT_ANVIL_GATEWAY = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    /// @dev Anvil default account #4 used as the seeded synthetic researcher wallet when DEMO_RESEARCHER_ADDRESS is unset.
    address internal constant DEFAULT_DEMO_RESEARCHER = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;

    uint256 internal constant DEFAULT_INITIAL_CREDITS = 1000;

    function run()
        external
        returns (RecordRegistry registry, ConsentManager consentManager, ResearchSettlement settlement)
    {
        address gatewayAddress = vm.envOr("GATEWAY_ADDRESS", DEFAULT_ANVIL_GATEWAY);
        address demoResearcher = vm.envOr("DEMO_RESEARCHER_ADDRESS", DEFAULT_DEMO_RESEARCHER);
        uint256 initialCredits = vm.envOr("DEMO_INITIAL_CREDITS", DEFAULT_INITIAL_CREDITS);

        vm.startBroadcast();
        registry = new RecordRegistry();
        consentManager = new ConsentManager(gatewayAddress);
        settlement = new ResearchSettlement(address(consentManager));
        if (demoResearcher != address(0) && initialCredits > 0) {
            settlement.mintTestCredits(demoResearcher, initialCredits);
        }
        vm.stopBroadcast();

        console2.log("RecordRegistry deployed at:", address(registry));
        console2.log("ConsentManager deployed at:", address(consentManager));
        console2.log("ResearchSettlement deployed at:", address(settlement));
        console2.log("Authorized gateway signer:", gatewayAddress);
        console2.log("Seeded researcher address:", demoResearcher);
        console2.log("Seeded researcher credits:", initialCredits);
    }
}
