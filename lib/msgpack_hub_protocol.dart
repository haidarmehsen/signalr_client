import 'dart:typed_data';
import 'package:logging/logging.dart';
import "package:message_pack_dart/message_pack_dart.dart" as msgpack;

import 'errors.dart';
import 'ihub_protocol.dart';
import 'itransport.dart';
import 'binary_message_format.dart';

const String msgPackHubProtocolName = "messagepack";
const int protocolVersion = 1;
const TransferFormat defaultTransferFormat = TransferFormat.binary;

class MessagePackHubProtocol implements IHubProtocol {
  @override
  String get name => msgPackHubProtocolName;
  @override
  TransferFormat get transferFormat => defaultTransferFormat;

  @override
  int get version => protocolVersion;

  static const _errorResult = 1;
  static const _voidResult = 2;
  static const _nonVoidResult = 3;

  @override
  List<HubMessageBase> parseMessages(Object input, Logger? logger) {
    if (input is! Uint8List) {
      throw GeneralError(
          "Invalid input for MessagePack hub protocol. Expected an Uint8List.");
    }

    final binaryInput = input;
    final List<HubMessageBase> hubMessages = [];

    final messages = BinaryMessageFormat.parse(binaryInput);
    if (messages.isEmpty) {
      throw GeneralError("Cannot encode message which is null.");
    }

    for (var message in messages) {
      if (message.isEmpty) {
        throw GeneralError("Cannot encode message which is null.");
      }

      final unpackedData = msgpack.deserialize(message);
      List<dynamic> unpackedList;
      if (unpackedData == null) {
        throw GeneralError("Cannot encode message which is null.");
      }
      try {
        unpackedList = List<dynamic>.from(unpackedData as List<dynamic>);
      } catch (_) {
        throw GeneralError("Invalid payload.");
      }
      if (unpackedList.isEmpty) {
        throw GeneralError("Cannot encode message which is null.");
      }
      final messageObj = _parseMessage(unpackedData, logger);
      if (messageObj != null) {
        hubMessages.add(messageObj);
      }
    }
    return hubMessages;
  }

  static HubMessageBase? _parseMessage(List<dynamic> data, Logger? logger) {
    if (data.isEmpty) {
      throw GeneralError("Invalid payload.");
    }
    HubMessageBase? messageObj;

    final messageType = data[0] as int;

    if (messageType == MessageType.invocation.index) {
      messageObj = _createInvocationMessage(data);
      return messageObj;
    }

    if (messageType == MessageType.streamItem.index) {
      messageObj = _createStreamItemMessage(data);
      return messageObj;
    }

    if (messageType == MessageType.completion.index) {
      messageObj = _createCompletionMessage(data);
      return messageObj;
    }

    if (messageType == MessageType.ping.index) {
      messageObj = _createPingMessage(data);
      return messageObj;
    }

    if (messageType == MessageType.close.index) {
      messageObj = _createCloseMessage(data);
      return messageObj;
    } else {
      // Future protocol changes can add message types, old clients can ignore them
      logger?.info("Unknown message type '$messageType' ignored.");
      // ignore: avoid_print
      print(data);
      return messageObj;
    }
  }

  static MessageHeaders createMessageHeaders(List<dynamic> data) {
    if (data.length < 2) {
      throw GeneralError("Invalid headers");
    } else {
      if (data[1] == null) return MessageHeaders();
      try {
        final headers1 = Map<String, String>.from(data[1]);
        final headers = MessageHeaders();
        headers1.forEach((key, value) {
          headers.setHeaderValue(key, value);
        });
        return headers;
      } catch (_) {
        throw GeneralError("Invalid headers");
      }
    }
  }

  static InvocationMessage _createInvocationMessage(List<dynamic> data) {
    if (data.length < 5) {
      throw GeneralError("Invalid payload for Invocation message.");
    }

    final MessageHeaders headers = createMessageHeaders(data);

    final message = InvocationMessage(
        target: data[3] as String?,
        headers: headers,
        invocationId: data[2] as String?,
        streamIds: [],
        arguments: List<Object>.from(data[4]));

    return message;
  }

  static StreamItemMessage _createStreamItemMessage(List<dynamic> data) {
    if (data.length < 4) {
      throw GeneralError("Invalid payload for StreamItem message.");
    }
    final MessageHeaders headers = createMessageHeaders(data);
    final message = StreamItemMessage(
      item: data[3] as Object?,
      headers: headers,
      invocationId: data[2] as String?,
    );

    return message;
  }

  static CompletionMessage _createCompletionMessage(List<dynamic> data) {
    if (data.length < 4) {
      throw GeneralError("Invalid payload for Completion message.");
    }
    final MessageHeaders headers = createMessageHeaders(data);
    final resultKind = data[3];
    if (resultKind != _voidResult && data.length < 5) {
      throw GeneralError("Invalid payload for Completion message.");
    }

    if (resultKind == _errorResult) {
      return CompletionMessage(
        error: data[4] as String?,
        result: null,
        headers: headers,
        invocationId: data[2] as String?,
      );
    } else if (resultKind == _nonVoidResult) {
      return CompletionMessage(
        result: data[4] as Object?,
        error: null,
        headers: headers,
        invocationId: data[2] as String?,
      );
    } else {
      return CompletionMessage(
        headers: headers,
        result: null,
        error: null,
        invocationId: data[2] as String?,
      );
    }
  }

  static PingMessage _createPingMessage(List<dynamic> data) {
    if (data.isEmpty) {
      throw GeneralError("Invalid payload for Ping message.");
    }
    return PingMessage();
  }

  static CloseMessage _createCloseMessage(List<dynamic> data) {
    if (data.length < 2) {
      throw GeneralError("Invalid payload for Close message.");
    }
    if (data.length >= 3) {
      return CloseMessage(allowReconnect: data[2], error: data[1]);
    } else {
      return CloseMessage(error: data[1]);
    }
  }

  @override
  Object writeMessage(HubMessageBase message) {
    final messageType = message.type;
    switch (messageType) {
      case MessageType.invocation:
        return _writeInvocation(message as InvocationMessage);
      case MessageType.streamInvocation:
        return _writeStreamInvocation(message as StreamInvocationMessage);
      case MessageType.streamItem:
        return _writeStreamItem(message as StreamItemMessage);
      case MessageType.completion:
        return _writeCompletion(message as CompletionMessage);
      case MessageType.ping:
        return _writePing();
      case MessageType.cancelInvocation:
        return _writeCancelInvocation(message as CancelInvocationMessage);
      default:
        throw GeneralError("Invalid message type.");
    }

    //throw GeneralError("Converting '${message.type}' is not implemented.");
  }

  static Uint8List _writeInvocation(InvocationMessage message) {
    List<dynamic> payload;

    if ((message.streamIds?.length ?? 0) > 0) {
      payload = [
        MessageType.invocation.index,
        message.headers.asMap,
        message.invocationId,
        message.target,
        message.arguments,
        message.streamIds
      ];
    } else {
      payload = [
        MessageType.invocation.index,
        message.headers.asMap,
        message.invocationId,
        message.target,
        message.arguments,
      ];
    }

    final packedData = msgpack.serialize(payload);
    return BinaryMessageFormat.write(packedData);
  }

  static Uint8List _writeStreamInvocation(StreamInvocationMessage message) {
    List<dynamic> payload;

    if ((message.streamIds?.length ?? 0) > 0) {
      payload = [
        MessageType.streamInvocation.index,
        message.headers.asMap,
        message.invocationId,
        message.target,
        message.arguments,
        message.streamIds
      ];
    } else {
      payload = [
        MessageType.streamInvocation.index,
        message.headers.asMap,
        message.invocationId,
        message.target,
        message.arguments,
      ];
    }

    final packedData = msgpack.serialize(payload);
    return BinaryMessageFormat.write(packedData);
  }

  static Uint8List _writeStreamItem(StreamItemMessage message) {
    List<dynamic> payload;

    payload = [
      MessageType.streamItem.index,
      message.headers.asMap,
      message.invocationId,
      message.item
    ];

    final packedData = msgpack.serialize(payload);
    return BinaryMessageFormat.write(packedData);
  }

  static Uint8List _writeCompletion(CompletionMessage message) {
    List<dynamic> payload;
    final resultKind = (message.error != null)
        ? _errorResult
        : (message.result != null)
            ? _nonVoidResult
            : _voidResult;
    if (resultKind == _errorResult) {
      payload = [
        MessageType.completion.index,
        message.headers.asMap,
        message.invocationId,
        resultKind,
        message.error
      ];
    } else if (resultKind == _nonVoidResult) {
      payload = [
        MessageType.completion.index,
        message.headers.asMap,
        message.invocationId,
        resultKind,
        message.result
      ];
    } else {
      payload = [
        MessageType.completion.index,
        message.headers.asMap,
        message.invocationId,
        resultKind
      ];
    }

    final packedData = msgpack.serialize(payload);
    return BinaryMessageFormat.write(packedData);
  }

  static Uint8List _writeCancelInvocation(CancelInvocationMessage message) {
    List<dynamic> payload;

    payload = [
      MessageType.cancelInvocation.index,
      message.headers.asMap,
      message.invocationId,
    ];

    final packedData = msgpack.serialize(payload);
    return BinaryMessageFormat.write(packedData);
  }

  static Uint8List _writePing() {
    List<dynamic> payload;

    payload = [
      MessageType.ping.index,
    ];

    final packedData = msgpack.serialize(payload);
    return BinaryMessageFormat.write(packedData);
  }
}
