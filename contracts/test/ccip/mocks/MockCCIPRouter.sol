// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CCIPTypes, ICCIPRouter, ICCIPReceiver} from "../../../src/ccip/CCIPTypes.sol";

/// @title MockCCIPRouter
/// @notice Test mock simulating Chainlink CCIP Router behavior.
///         When `ccipSend` is called, it can optionally deliver the message
///         to a receiver contract on the same chain (for integration tests).
contract MockCCIPRouter is ICCIPRouter {
    uint256 public constant FIXED_FEE = 0.01 ether;

    uint256 private _messageCounter;
    bool public autoDeliver;

    // Last sent message (for assertions)
    CCIPTypes.EVM2AnyMessage internal _lastMessage;
    uint64 public lastDestChainSelector;
    bytes32 public lastMessageId;

    constructor() {
        autoDeliver = false;
    }

    function setAutoDeliver(bool enabled) external {
        autoDeliver = enabled;
    }

    function isChainSupported(uint64) external pure returns (bool) {
        return true;
    }

    function getFee(uint64, CCIPTypes.EVM2AnyMessage memory) external pure returns (uint256) {
        return FIXED_FEE;
    }

    function ccipSend(
        uint64 destinationChainSelector,
        CCIPTypes.EVM2AnyMessage calldata message
    ) external payable returns (bytes32 messageId) {
        require(msg.value >= FIXED_FEE, "MockCCIPRouter: insufficient fee");

        messageId = keccak256(abi.encodePacked(block.timestamp, _messageCounter++));
        _lastMessage = message;
        lastDestChainSelector = destinationChainSelector;
        lastMessageId = messageId;

        // Auto-deliver to receiver if enabled (for integration testing)
        if (autoDeliver) {
            address receiver = abi.decode(message.receiver, (address));
            CCIPTypes.Any2EVMMessage memory inboundMsg = CCIPTypes.Any2EVMMessage({
                messageId: messageId,
                sourceChainSelector: destinationChainSelector,
                sender: abi.encode(msg.sender),
                data: message.data,
                destTokenAmounts: new CCIPTypes.EVMTokenAmount[](0)
            });
            ICCIPReceiver(receiver).ccipReceive(inboundMsg);
        }

        return messageId;
    }

    /// @notice Returns the last message sent via ccipSend.
    function getLastMessage() external view returns (CCIPTypes.EVM2AnyMessage memory) {
        return _lastMessage;
    }

    // Allow the mock to receive ETH
    receive() external payable {}
}
