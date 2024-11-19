//SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {LinkToken} from "../../src/test/LinkToken.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2Mock} from "../../src/test/VRFCoordinatorV2Mock.sol";

contract RaffleUnitTests is Test {
    DeployRaffle deployRaffle;
    Raffle raffle;
    address prankaddress = vm.addr(1);
    uint256 fundval = 10 ether;
    event Lotteryenter(address indexed playeraddress);
    address payable private s_recentwinner;
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(
        uint256 requestId,
        uint256[] randomWords,
        uint256 payment
    );
    event WinnerPicked(address payable indexed winner);
    address linkTokenaddress;
    address vrfcoordinatoraddress;
    address v2wrapperaddress;
    uint96 linkamount = 1000 ether;

    function setUp() public {
        deployRaffle = new DeployRaffle();
        raffle = deployRaffle.run();
        linkTokenaddress = deployRaffle.getlinkaddress();
        vrfcoordinatoraddress = deployRaffle.getvrfcoordinatoraddress();
        v2wrapperaddress = deployRaffle.getv2wrapperaddress();
    }

    function test_lotterystateisopenondeployment() public view {
        Raffle.s_lotterystate lotterystate = raffle.getlotterystate();
        assertEq(uint256(lotterystate), uint256(Raffle.s_lotterystate.open));
    }

    function test_RevertIf_entrancefeeisnotmet() public {
        hoax(prankaddress, fundval);
        bytes4 selector = bytes4(keccak256("Raffle__NotEnoughETH()"));
        vm.expectRevert(selector);
        raffle.enterlottery{value: 0.03 ether}();
    }

    function test_funderisloggedafterfundingcontract() public {
        hoax(prankaddress, fundval);
        raffle.enterlottery{value: 0.05 ether}();
        console.log();
        address player = raffle.getplayer(0);
        assertEq(player, prankaddress);
    }

    function test_lotteryentereventemits() public payable {
        vm.expectEmit(address(raffle));
        emit Lotteryenter(prankaddress);

        hoax(prankaddress, fundval);
        raffle.enterlottery{value: 0.05 ether}();
    }

    function test_RevertIf_lotteryisincalculatingstate() public {
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        vm.deal(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, fundval);
        raffle.enterlottery{value: 0.05 ether}();
        vm.warp(block.timestamp + raffle.getinterval() + 1);
        vm.roll(block.number + 1);
        raffle.checkUpkeep("0x");
        LinkToken linkToken = LinkToken(linkTokenaddress);
        linkToken.transfer(address(raffle), linkamount);
        console.log(linkToken.balanceOf(address(raffle)));
        raffle.performUpkeep("0x");
        vm.stopPrank();

        vm.expectRevert(Raffle.Raffle__LotteryNotOpen.selector);
        raffle.enterlottery{value: 0.05 ether}();
    }

    function test_checkupkeepreturnsfalseifcontracthasnobalance() public {
        vm.warp(block.timestamp + raffle.getinterval() + 1);
        vm.roll(block.number + 1);
        (bool upkeep, ) = raffle.checkUpkeep("0x");
        assertEq(upkeep, false);
    }

    function test_checkupkeepreturnsfalseiflotteryisntopen() public {
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        vm.deal(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, fundval);
        raffle.enterlottery{value: 0.05 ether}();
        vm.warp(block.timestamp + raffle.getinterval() + 1);
        vm.roll(block.number + 1);
        raffle.checkUpkeep("0x");
        LinkToken linkToken = LinkToken(linkTokenaddress);
        linkToken.transfer(address(raffle), linkamount);
        raffle.performUpkeep("0x");
        (bool upkeep, ) = raffle.checkUpkeep("0x");
        vm.stopPrank();

        assertEq(upkeep, false);
    }

    function test_performupkeepcanbecalledwhencheckupkeepreturnstrue() public {
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        vm.deal(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, fundval);
        raffle.enterlottery{value: 0.05 ether}();
        vm.warp(block.timestamp + raffle.getinterval() + 1);
        vm.roll(block.number + 1);
        raffle.checkUpkeep("0x");
        LinkToken linkToken = LinkToken(linkTokenaddress);
        linkToken.transfer(address(raffle), linkamount);
        (bool success, ) = address(raffle).call(
            abi.encodeWithSelector(0x4585e33b, "0x")
        );
        vm.stopPrank();
        assertTrue(success);
    }

    function test_performupkeepcannotbecalledifcheckupkeepisfalse() public {
        vm.expectRevert(Raffle.Raffle__UpkeepNotNeeded.selector);
        raffle.performUpkeep("0x");
    }

    modifier checkupkeepfulfilled() {
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        vm.deal(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, fundval);
        raffle.enterlottery{value: 0.05 ether}();
        vm.warp(block.timestamp + raffle.getinterval() + 1);
        vm.roll(block.number + 1);
        raffle.checkUpkeep("0x");
        LinkToken linkToken = LinkToken(linkTokenaddress);
        linkToken.transfer(address(raffle), linkamount);
        vm.stopPrank();
        _;
    }

    function test_performupkeepcanemitcorrectevents()
        public
        checkupkeepfulfilled
    {
        vm.recordLogs();
        raffle.performUpkeep("0x");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertGt(uint256(entries[3].topics[1]), 0);
        assertEq(entries[3].data, abi.encode(uint256(1)));
    }

    function test_RevertIf_requestidfulfillrandomwordsnotvalid(
        uint256 randomId
    ) public checkupkeepfulfilled {
        vm.assume(randomId > 1);
        raffle.performUpkeep("0x");
        VRFCoordinatorV2Mock vrfcoordinator = VRFCoordinatorV2Mock(
            vrfcoordinatoraddress
        );
        vm.expectRevert("nonexistent request");
        vrfcoordinator.fulfillRandomWords(randomId, v2wrapperaddress);
    }

    function test_fufillrandomwordsworksandpaystowinner()
        public
        checkupkeepfulfilled
    {
        uint256 numofplayers = 5;
        for (uint256 i = 1; i < numofplayers; i++) {
            address hoaxaddress = vm.addr(i);
            vm.startPrank(hoaxaddress);
            vm.deal(hoaxaddress, fundval);
            raffle.enterlottery{value: i * 0.1 ether}();
            vm.stopPrank();
        }
        VRFCoordinatorV2Mock vrfcoordinator = VRFCoordinatorV2Mock(
            vrfcoordinatoraddress
        );
        vm.recordLogs();
        raffle.performUpkeep("0x");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        uint256 requestId = uint256(entries[3].topics[1]);
        console.log(requestId);
        console.log(address(vrfcoordinator));
        vrfcoordinator.fulfillRandomWords(requestId, v2wrapperaddress);
        Vm.Log[] memory entries2 = vm.getRecordedLogs();
        assertNotEq(raffle.getwinner(), address(0));
        assertEq(
            raffle.getwinner(),
            address(uint160(uint256(entries2[1].topics[1])))
        );
        assertEq(address(raffle).balance, 0);
        assertEq(block.timestamp, raffle.getlatestblocktimestamp());
        assertEq(
            uint256(raffle.getlotterystate()),
            uint256(Raffle.s_lotterystate.open)
        );
    }
}
