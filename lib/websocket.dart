import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// A class that facilitates WebSocket connections.
///
/// This class helps in establishing a WebSocket connection with a specified domain
/// and provides methods to send messages and close the connection.
class SimpleWebSocket {
  final String _domain;
  final Map<String, dynamic> _queryParams;
  WebSocket? _socket;

  /// Callback invoked when the WebSocket connection is opened successfully.
  Function()? onOpen;

  /// Callback invoked when a message is received on the WebSocket.
  Function(dynamic msg)? onMessage;

  /// Callback invoked when the WebSocket connection is closed.
  Function(int? code, String? reaso)? onClose;

  /// Constructs a SimpleWebSocket instance with the specified domain and query parameters.
  ///
  /// The [domain] parameter represents the domain or host address of the WebSocket server.
  /// The [queryParams] parameter contains additional query parameters to be included in the WebSocket URL.
  SimpleWebSocket(this._domain, this._queryParams);

  /// Establishes a WebSocket connection.
  ///
  /// This method establishes a WebSocket connection using a self-signed certificate.
  /// It invokes the [onOpen] callback when the connection is successfully opened.
  /// Messages received trigger the [onMessage] callback, and connection closure invokes [onClose].
  connect() async {
    try {
      _socket = await _connectForSelfSignedCert();
      onOpen?.call();
      _socket?.listen((data) {
        onMessage?.call(data);
      }, onDone: () {
        onClose?.call(_socket?.closeCode, _socket?.closeReason);
      });
    } catch (e) {
      onClose?.call(500, e.toString());
    }
  }

  /// Sends a message through the WebSocket connection.
  ///
  /// The [data] parameter represents the message to be sent through the WebSocket.
  send(data) {
    if (_socket != null) {
      _socket?.add(data);
    }
  }

  /// Closes the WebSocket connection.
  ///
  /// This method closes the WebSocket connection if it is open and nullifies the socket reference.
  close() {
    if (_socket != null) _socket?.close();
  }

  /// Connects to the WebSocket server using a self-signed certificate.
  ///
  /// This private method handles the WebSocket connection creation with necessary headers.
  Future<WebSocket> _connectForSelfSignedCert() async {
    try {
      Random r = Random();
      String key = base64.encode(List<int>.generate(8, (_) => r.nextInt(255)));
      HttpClient client = HttpClient(context: SecurityContext());
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        if (kDebugMode) {
          print(
              'SimpleWebSocket: Allow self-signed certificate => $host:$port. ');
        }
        return true;
      };

      final uri = Uri.https(_domain, '', _queryParams);
      HttpClientRequest request = await client.getUrl(uri);
      request.headers.add('content-type', 'application/json');
      request.headers.add("Accept", "application/json");
      request.headers.add('Connection', 'Upgrade');
      request.headers.add('Upgrade', 'websocket');
      request.headers.add('Sec-WebSocket-Version', '13');
      request.headers.add('Sec-WebSocket-Key', key.toLowerCase());
      HttpClientResponse response = await request.close();
      Socket socket = await response.detachSocket();
      var webSocket = WebSocket.fromUpgradedSocket(socket, serverSide: false);

      return webSocket;
    } catch (e) {
      rethrow;
    }
  }
}
