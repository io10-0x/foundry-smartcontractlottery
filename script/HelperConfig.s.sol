//SDPX-License-Identifier: MIT

pragma solidity ^0.8.6;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {MockV3Aggregator} from "../src/test/MockV3Aggregator.sol";
import {LinkToken} from "../src/test/LinkToken.sol";
import {VRFV2Wrapper} from "../src/test/VRFV2Wrapper.sol";
import {VRFCoordinatorV2Mock} from "../src/test/VRFCoordinatorV2Mock.sol";

contract HelperConfig is Script {
    LinkToken linkToken;
    struct NetworkConfig {
        uint256 entrancefee;
        address linktokenaddress;
        address v2WrapperAddress;
    }
    NetworkConfig public activeConfig;
    uint256 constant ENTRANCEFEE = 0.05 ether;
    VRFCoordinatorV2Mock vrfCoordinator;

    constructor() {
        if (block.chainid == 11155111) {
            activeConfig = getsepoliaconfig();
        } else if (block.chainid == 31337) {
            activeConfig = getanvilconfig();
        }
    }

    function getsepoliaconfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig(
                ENTRANCEFEE,
                0x779877A7B0D9E8603169DdbD7836e478b4624789,
                0xab18414CD93297B0d12ac29E63Ca20f515b3DB46
            );
    }

    function getanvilconfig() public returns (NetworkConfig memory) {
        uint8 decimals = 8;
        int256 initialPrice = 200000000000;
        uint96 _BASEFEE = 0.25 ether;
        uint96 _GASPRICELINK = 100000;
        uint96 linkamount = 1000 ether;
        uint32 _wrapperGasOverhead = 60000;
        uint32 _coordinatorGasOverhead = 52000;
        uint8 _wrapperPremiumPercentage = 10;
        bytes32 _keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
        uint8 _maxNumWords = 10;
        vm.startBroadcast(
            0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        );
        MockV3Aggregator mockV3Aggregator = new MockV3Aggregator(
            decimals,
            initialPrice
        );
        linkToken = new LinkToken();
        vrfCoordinator = new VRFCoordinatorV2Mock(_BASEFEE, _GASPRICELINK);
        VRFV2Wrapper vrfV2Wrapper = new VRFV2Wrapper(
            address(linkToken),
            address(mockV3Aggregator),
            address(vrfCoordinator)
        );
        vrfV2Wrapper.setConfig(
            _wrapperGasOverhead,
            _coordinatorGasOverhead,
            _wrapperPremiumPercentage,
            _keyHash,
            _maxNumWords
        );
        console.log("Config function works !");
        vrfCoordinator.fundSubscription(1, linkamount);
        vm.stopBroadcast();
        return
            NetworkConfig(
                ENTRANCEFEE,
                address(linkToken),
                address(vrfV2Wrapper)
            );
    }

    //getter
    function getvrfcoordinatoraddress() public view returns (address) {
        return address(vrfCoordinator);
    }
}
