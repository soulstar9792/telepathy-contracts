pragma solidity 0.8.14;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

import {Bytes32} from "src/libraries/Typecast.sol";

import {ITelepathyBroadcaster, Message} from "./interfaces/ITelepathy.sol";
import {SourceAMBStorage} from "./SourceAMBStorage.sol";

/// @title Telepathy Source Arbitrary Message Bridge
/// @author Succinct Labs
/// @notice This contract is the entrypoint for making a cross-chain call.
contract SourceAMB is
    SourceAMBStorage,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ITelepathyBroadcaster
{
    /// @notice Returns current contract version.
    uint8 public constant VERSION = 1;

    /// @notice Initializes the contract and the parent contracts once.
    function initialize() external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    /// @notice Sends a message to a target chain.
    /// @notice This method is more expensive than the `sendViaLog` method as it requires adding to
    ///         contract storage. Use `sendViaLog` when interacting with Telepathy to save gas.
    /// @param _recipientChainId The chain id that specifies the target chain.
    /// @param _recipientAddress The contract address that will be called on the target chain.
    /// @param _data The data passed to the contract on the other chain
    /// @return bytes32 A unique identifier for a message.
    function send(uint16 _recipientChainId, bytes32 _recipientAddress, bytes calldata _data)
        external
        returns (bytes32)
    {
        (bytes memory message, bytes32 messageRoot) =
            _getMessageAndRoot(_recipientChainId, _recipientAddress, _data);
        messages[nonce] = messageRoot;
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    function send(uint16 _recipientChainId, address _recipientAddress, bytes calldata _data)
        external
        returns (bytes32)
    {
        (bytes memory message, bytes32 messageRoot) =
            _getMessageAndRoot(_recipientChainId, Bytes32.fromAddress(_recipientAddress), _data);
        messages[nonce] = messageRoot;
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    /// @notice Sends a message to a target chain using an event log instead of a storage slot.
    /// @notice This method is cheaper than the `send` method as it does not require adding to contract storage.
    /// It is the recommended method for interacting with the Telepathy messaging protocol.
    /// @param _recipientChainId The chain id that specifies the target chain.
    /// @param _recipientAddress The contract address that will be called on the target chain.
    /// @param _data The data passed to the contract on the other chain
    /// @return bytes32 A unique identifier for a message.
    function sendViaLog(uint16 _recipientChainId, bytes32 _recipientAddress, bytes calldata _data)
        external
        returns (bytes32)
    {
        (bytes memory message, bytes32 messageRoot) =
            _getMessageAndRoot(_recipientChainId, _recipientAddress, _data);
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    function sendViaLog(uint16 _recipientChainId, address _recipientAddress, bytes calldata _data)
        external
        returns (bytes32)
    {
        (bytes memory message, bytes32 messageRoot) =
            _getMessageAndRoot(_recipientChainId, Bytes32.fromAddress(_recipientAddress), _data);
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    /// @notice Gets the message and message root from the user-provided arguments to `send`
    /// @param _recipientChainId The chain id that specifies the target chain.
    /// @param _recipientAddress The contract address that will be called on the target chain.
    /// @param _data The calldata used when calling the contract on the target chain.
    /// @return messageBytes The message encoded as bytes, used in SentMessage event.
    /// @return messageRoot The hash of messageBytes, used as a unique identifier for a message.
    function _getMessageAndRoot(
        uint16 _recipientChainId,
        bytes32 _recipientAddress,
        bytes calldata _data
    ) internal view returns (bytes memory messageBytes, bytes32 messageRoot) {
        Message memory message = Message({
            nonce: nonce,
            sourceChainId: uint16(block.chainid),
            senderAddress: msg.sender,
            recipientAddress: _recipientAddress,
            recipientChainId: _recipientChainId,
            data: _data
        });
        messageBytes = abi.encode(message);
        messageRoot = keccak256(messageBytes);
    }

    /// @notice Authorizes an upgrade for the implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
