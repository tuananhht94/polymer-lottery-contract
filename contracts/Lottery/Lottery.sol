// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import '../base/CustomChanIbcApp.sol';

contract Lottery is CustomChanIbcApp {
    enum IbcPacketStatus {UNSENT, SENT, ACKED, TIMEOUT}

    struct WinnerHistory {
        address winner;
        uint256 amount;
        uint256 counter;
        IbcPacketStatus ibcPacketStatus;
    }

    address[] public players;
    uint256 public counter;
    uint256 public betAmount = 0.1 ether;
    mapping(uint256 => WinnerHistory) public winnerHistories;

    event Enter(address indexed _from, uint256 _value, uint256 _counter);
    event Winner(address indexed _winner, uint256 _value, uint256 _counter);
    event SendWinnerInfo(bytes32 indexed channelId, address winner, uint256 amount, uint256 counter);
    event AckRewardSent(bytes32 indexed channelId, uint64 sequence, address winner, uint256 amount, uint256 counter);

    constructor(IbcDispatcher _dispatcher) CustomChanIbcApp(_dispatcher) {
        operators.push(msg.sender);
    }

    function getPlayers() public view returns (address[] memory) {
        return players;
    }

    function setBetAmount(uint256 _betAmount) public onlyOwner {
        betAmount = _betAmount;
    }

    function enter() public payable {
        require(msg.value == betAmount, "Invalid amount");
        players.push(msg.sender);
        emit Enter(msg.sender, msg.value, counter);
    }

    function random() public view returns (uint256) {
        uint256 blockValue = uint256(blockhash(block.number - 1));
        return uint256(keccak256(abi.encodePacked(blockValue, block.timestamp)));
    }

    function pickWinner(
        bytes32 channelId,
        uint64 timeoutSeconds
    ) public onlyOperator returns (WinnerHistory memory) {
        address payable winner = payable(players[random() % players.length]);
        uint256 amount = address(this).balance;
        winner.transfer(amount);
        players = new address[](0);
        counter = counter + 1;
        winnerHistories[counter] = WinnerHistory(winner, amount, counter, IbcPacketStatus.UNSENT);
        sendPacket(channelId, timeoutSeconds, counter);
        emit Winner(winner, amount, counter);
        return winnerHistories[counter];
    }

    function sendPacket(
        bytes32 channelId,
        uint64 timeoutSeconds,
        uint256 _counter
    ) public {
        WinnerHistory storage winnerHistory = winnerHistories[_counter];
        require(winnerHistory.ibcPacketStatus == IbcPacketStatus.UNSENT || winnerHistory.ibcPacketStatus == IbcPacketStatus.TIMEOUT, "Packet already sent");

        address winner = winnerHistory.winner;
        uint256 amount = winnerHistory.amount;
        bytes memory payload = abi.encode(winner, amount, _counter);

        uint64 timeoutTimestamp = uint64((block.timestamp + timeoutSeconds) * 1000000000);

        dispatcher.sendPacket(channelId, payload, timeoutTimestamp);
        winnerHistory.ibcPacketStatus = IbcPacketStatus.SENT;

        emit SendWinnerInfo(channelId, winner, amount, _counter);
    }

    function onRecvPacket(IbcPacket memory) external override view onlyIbcDispatcher returns (AckPacket memory ackPacket) {
        require(false, "This function should not be called");

        return AckPacket(true, abi.encode("Error: This function should not be called"));
    }

    function onAcknowledgementPacket(IbcPacket calldata packet, AckPacket calldata ack) external override onlyIbcDispatcher {
        ackPackets.push(ack);

        // decode the ack data, find the address of the voter the packet belongs to and set ibcNFTMinted true
        (address winner, uint256 amount, uint256 _counter) = abi.decode(ack.data, (address, uint256, uint256));
        winnerHistories[_counter].ibcPacketStatus = IbcPacketStatus.ACKED;

        emit AckRewardSent(packet.src.channelId, packet.sequence, winner, amount, _counter);
    }

    function onTimeoutPacket(IbcPacket calldata packet) external override onlyIbcDispatcher {
        timeoutPackets.push(packet);
        // do logic
    }
}
