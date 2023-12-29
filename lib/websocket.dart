import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

class SimpleWebSocket {
  final String _domain;
  final Map<String, dynamic> _queryParams;
  WebSocket? _socket;
  Function()? onOpen;
  Function(dynamic msg)? onMessage;
  Function(int? code, String? reaso)? onClose;

  SimpleWebSocket(this._domain, this._queryParams);

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

  send(data) {
    if (_socket != null) {
      _socket?.add(data);
    }
  }

  close() {
    if (_socket != null) _socket?.close();
  }

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
