import 'dart:async';

import 'errors.dart';

/// Specifies a specific HTTP transport type.
enum HttpTransportType {
  /// Specified no transport preference. */
  none, // = 0,
  /// Specifies the WebSockets transport. */
  webSockets, // = 1,
  /// Specifies the Server-Sent Events transport. */
  serverSentEvents, // = 2,
  /// Specifies the Long Polling transport. */
  longPolling, // = 4,
}

HttpTransportType httpTransportTypeFromString(String? value) {
  if (value == null || value == "") {
    return HttpTransportType.none;
  }

  value = value.toUpperCase();
  switch (value) {
    case "WEBSOCKETS":
      return HttpTransportType.webSockets;
    case "SERVERSENTEVENTS":
      return HttpTransportType.serverSentEvents;
    case "LONGPOLLING":
      return HttpTransportType.longPolling;
    default:
      throw GeneralError("$value is not a supported HttpTransportType");
  }
}

/// Specifies the transfer format for a connection.
enum TransferFormat {
  /// TransferFormat is not defined.
  undefined, // = 0,
  /// Specifies that only text data will be transmitted over the connection.
  text, // = 1,
  /// Specifies that binary data will be transmitted over the connection.
  binary, // = 2,
}

TransferFormat getTransferFormatFromString(String? value) {
  if (value == null || value == "") {
    return TransferFormat.undefined;
  }

  value = value.toUpperCase();
  switch (value) {
    case "TEXT":
      return TransferFormat.text;
    case "BINARY":
      return TransferFormat.binary;
    default:
      throw GeneralError("$value is not a supported HttpTransportType");
  }
}

/// Data received call back.
/// data: the content. Either a string (json) or Uint8List (binary)
typedef OnReceive = void Function(Object? data);

///
typedef OnClose = void Function({Exception? error});

typedef AccessTokenFactory = Future<String> Function();

/// An abstraction over the behavior of transports. This is designed to support the framework and not intended for use by applications.
abstract class ITransport {
  Future<void> connect(String? url, TransferFormat transferFormat);

  /// data: the content. Either a string (json) or Uint8List (binary)
  Future<void> send(Object data);
  Future<void> stop();
  OnReceive? onReceive;
  OnClose? onClose;
}
