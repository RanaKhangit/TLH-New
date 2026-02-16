// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CCIPTypes
/// @notice Minimal CCIP type definitions extracted from Chainlink Client.sol.
///         Only includes structs/constants needed by TLH CCIP contracts, avoiding
///         the SVM/SUI constants that cause stack-too-deep compilation errors.
library CCIPTypes {
    struct EVMTokenAmount {
        address token;
        uint256 amount;
    }

    struct Any2EVMMessage {
        bytes32 messageId;
        uint64 sourceChainSelector;
        bytes sender;
        bytes data;
        EVMTokenAmount[] destTokenAmounts;
    }

    struct EVM2AnyMessage {
        bytes receiver;
        bytes data;
        EVMTokenAmount[] tokenAmounts;
        address feeToken;
        bytes extraArgs;
    }

    bytes4 public constant EVM_EXTRA_ARGS_V1_TAG = 0x97a657c9;

    struct EVMExtraArgsV1 {
        uint256 gasLimit;
    }

    function _argsToBytes(EVMExtraArgsV1 memory extraArgs) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(EVM_EXTRA_ARGS_V1_TAG, extraArgs);
    }
}

/// @notice Minimal CCIP Router interface.
interface ICCIPRouter {
    function isChainSupported(uint64 destChainSelector) external view returns (bool);

    function getFee(
        uint64 destinationChainSelector,
        CCIPTypes.EVM2AnyMessage memory message
    ) external view returns (uint256 fee);

    function ccipSend(
        uint64 destinationChainSelector,
        CCIPTypes.EVM2AnyMessage calldata message
    ) external payable returns (bytes32);
}

/// @notice Minimal IAny2EVMMessageReceiver interface.
interface ICCIPReceiver {
    function ccipReceive(CCIPTypes.Any2EVMMessage calldata message) external;
}
