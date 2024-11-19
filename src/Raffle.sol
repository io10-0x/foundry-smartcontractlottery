// SPDX-License-Identifier: MIT
//Raffle
//Enter lottery
//Pick a random winner (verifiably random)
//Winner to be selected every X minutes (completely automate)
//Chainlink Oracle => Randomness, Automated Execution (Chainlink Keepers)

pragma solidity ^0.8.6;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {VRFV2WrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title A sample Raffle Contract
 * @author Ivan Otono
 * @notice This contract allows users to enter a raffle and be able to win ETH
 * @dev This implements Chainlink VRF and Chainlink Automation
 */

contract Raffle is
    VRFV2WrapperConsumerBase,
    ConfirmedOwner,
    AutomationCompatibleInterface
{
    enum s_lotterystate {
        open,
        calculating_winner
    }
    s_lotterystate private s_currentlotterystate;
    uint256 private immutable i_entrancefee;
    uint256 private constant INTERVAL = 30;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    event Lotteryenter(address indexed playeraddress);
    address payable private s_recentwinner;
    event RequestSent(uint256 indexed requestId, uint32 numWords);
    event RequestFulfilled(
        uint256 requestId,
        uint256[] randomWords,
        uint256 payment
    );
    event WinnerPicked(address payable indexed winner);

    struct RequestStatus {
        uint256 paid; // amount paid in link
        bool fulfilled; // whether the request has been successfully fulfilled
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 private constant CALLBACKGASLIMIT = 500000;

    // The default is 3, but you can set this higher.
    uint16 private constant REQUESTCONFIRMATIONS = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFV2Wrapper.getConfig().maxNumWords.
    uint32 private constant NUMWORDS = 1;

    error Raffle__NotEnoughETH();
    error Raffle__TransferFailed();
    error Raffle__LotteryNotOpen();
    error Raffle__UpkeepNotNeeded();

    constructor(
        uint256 entrancefee,
        address linktokenaddress,
        address v2WrapperAddress
    )
        ConfirmedOwner(msg.sender)
        VRFV2WrapperConsumerBase(linktokenaddress, v2WrapperAddress)
    {
        i_entrancefee = entrancefee;
        s_currentlotterystate = s_lotterystate.open;
        s_lastTimeStamp = block.timestamp;
    }

    function enterlottery() public payable {
        if (msg.value < i_entrancefee) {
            revert Raffle__NotEnoughETH();
        }
        if (s_currentlotterystate != s_lotterystate.open) {
            revert Raffle__LotteryNotOpen();
        }

        s_players.push(payable(msg.sender));
        emit Lotteryenter(msg.sender);
    }

    function checkUpkeep(
        bytes calldata checkData
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /*performData*/)
    {
        if (
            (s_currentlotterystate == s_lotterystate.open) &&
            ((block.timestamp - s_lastTimeStamp) > INTERVAL) &&
            (address(this).balance > 0) &&
            (s_players.length > 0)
        ) {
            return (true, checkData);
        } else {
            return (false, checkData);
        }
    }

    function performUpkeep(bytes calldata performData) external override {
        (bool upkeepNeeded, ) = checkUpkeep(performData);
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded();
        }
        uint256 requestId = requestRandomness(
            CALLBACKGASLIMIT,
            REQUESTCONFIRMATIONS,
            NUMWORDS
        );
        s_requests[requestId] = RequestStatus({
            paid: VRF_V2_WRAPPER.calculateRequestPrice(CALLBACKGASLIMIT),
            randomWords: new uint256[](0),
            fulfilled: false
        });
        s_currentlotterystate = s_lotterystate.calculating_winner;
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, NUMWORDS);
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].paid > 0, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(
            _requestId,
            _randomWords,
            s_requests[_requestId].paid
        );
        uint256 randomNumber = _randomWords[0] % s_players.length;
        address payable winningaddress = s_players[randomNumber];
        s_recentwinner = winningaddress;

        (bool success, ) = winningaddress.call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert Raffle__TransferFailed();
        }
        s_players = new address payable[](0);
        emit WinnerPicked(winningaddress);
        s_currentlotterystate = s_lotterystate.open;
        s_lastTimeStamp = block.timestamp;
    }

    function getentrancefee() public view returns (uint256) {
        return i_entrancefee;
    }

    function getlatestblocktimestamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getlotterystate() public view returns (s_lotterystate) {
        return s_currentlotterystate;
    }

    function getnumplayers() public view returns (uint256) {
        return s_players.length;
    }

    function getplayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getwinner() public view returns (address payable) {
        return s_recentwinner;
    }

    function getNumWords() public pure returns (uint256 numwords) {
        return NUMWORDS;
    }

    function getcallbackgaslimit() public pure returns (uint256 gaslimit) {
        return CALLBACKGASLIMIT;
    }

    function getinterval() public pure returns (uint256 interval) {
        return INTERVAL;
    }
}
