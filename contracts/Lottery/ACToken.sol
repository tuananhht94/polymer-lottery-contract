// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import '../base/CustomChanIbcApp.sol';

contract ACToken is ERC20, Pausable, CustomChanIbcApp {
    using SafeMath for uint256;

    uint256 public constant cap = 5000000000 ether;

    event MintedOnRecv(bytes32 indexed channelId, uint64 sequence, address winner, uint256 amount, uint256 counter);

    constructor(IbcDispatcher _dispatcher) CustomChanIbcApp(_dispatcher) Pausable() ERC20("AC", "AC") {}

    function pause() external virtual onlyOwner {
        _pause();
    }

    function unpause() external virtual onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "ACToken: token transfer while paused");
        if (from == address(0)) {
            require(
                totalSupply().add(amount) <= cap,
                "ACToken: cap exceeded"
            );
        }
    }

    function mint(address to, uint256 amount) external virtual onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external virtual {
        _burn(msg.sender, amount);
    }

    function onRecvPacket(IbcPacket memory packet) external override onlyIbcDispatcher returns (AckPacket memory ackPacket) {
        recvedPackets.push(packet);

        // Decode the packet data
        (address decodedWinner, uint256 decodedAmount, uint256 decodedCounter) = abi.decode(packet.data, (address, uint256, uint256));

        // Mint token
        _mint(decodedWinner, decodedAmount);
        emit MintedOnRecv(packet.dest.channelId, packet.sequence, decodedWinner, decodedAmount, decodedCounter);

        // Encode the ack data
        bytes memory ackData = abi.encode(decodedWinner, decodedAmount, decodedCounter);

        return AckPacket(true, ackData);
    }

    function onAcknowledgementPacket(IbcPacket calldata, AckPacket calldata) external view override onlyIbcDispatcher {
        require(false, "This contract should never receive an acknowledgement packet");
    }

    function onTimeoutPacket(IbcPacket calldata) external view override onlyIbcDispatcher {
        require(false, "This contract should never receive a timeout packet");
    }
}
