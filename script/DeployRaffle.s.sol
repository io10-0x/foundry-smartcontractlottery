//SDPX-License-Identifier: MIT

pragma solidity ^0.8.6;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRaffle is Script {
    uint256 entrancefee;
    address linktokenaddress;
    address v2WrapperAddress;
    address vrfcoordinatoraddress;

    function run() external returns (Raffle) {
        HelperConfig helperconfig = new HelperConfig();
        vrfcoordinatoraddress = helperconfig.getvrfcoordinatoraddress();
        (entrancefee, linktokenaddress, v2WrapperAddress) = helperconfig
            .activeConfig();
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entrancefee,
            linktokenaddress,
            v2WrapperAddress
        );
        vm.stopBroadcast();
        return raffle;
    }

    function getlinkaddress() external view returns (address) {
        return linktokenaddress;
    }

    function getvrfcoordinatoraddress() external view returns (address) {
        return vrfcoordinatoraddress;
    }

    function getv2wrapperaddress() external view returns (address) {
        return v2WrapperAddress;
    }
}
