import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

Future<Uint8List> getSignatureKey(String dateString, String secretAccessKey,
    String region, String service) async {
  List<int> kDate = Hmac(sha256, utf8.encode('AWS4$secretAccessKey'))
      .convert(utf8.encode(dateString))
      .bytes;
  List<int> kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
  List<int> kService =
      Hmac(sha256, kRegion).convert(utf8.encode(service)).bytes;
  List<int> kSigning =
      Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;

  return Uint8List.fromList(kSigning);
}

Future<String> sha(String message) async {
  // Convert the string message to bytes
  List<int> bytes = utf8.encode(message);

  // Compute the SHA-256 hash
  Digest hash = sha256.convert(bytes);

  // Convert the hash bytes to a hexadecimal string
  String hashHex = hash.toString();

  return hashHex;
}

String createQueryString(Map<String, dynamic> queryParams) {
  List<String> keys = queryParams.keys.toList()..sort(); // Get sorted keys

  List<String> queryList = keys.map((key) {
    String encodedValue = Uri.encodeComponent(queryParams[key]!);
    return '$key=$encodedValue';
  }).toList();

  String queryString = queryList.join('&');

  return queryString;
}

String getRandomClientId() {
  Random random = Random();
  String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  String randomString = '';

  for (int i = 0; i < 10; i++) {
    randomString += chars[random.nextInt(chars.length)];
  }

  return randomString.toUpperCase();
}

Future<String> calculateSignature(String key, String stringToSign) async {
  List<int> secretKey = utf8.encode(key);
  List<int> message = utf8.encode(stringToSign);

  Hmac hmacSha256 = Hmac(sha256, secretKey);
  Digest signature = hmacSha256.convert(message);

  return signature.toString();
}

String toHex(ByteBuffer buffer) {
  // Create a Uint8List view of the buffer
  Uint8List uint8List = Uint8List.view(buffer);

  // Convert each byte to a hexadecimal string and join them
  String hexString =
      uint8List.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');

  return hexString;
}

Future<Uint8List> hmac(dynamic key, String message) async {
  Uint8List keyBuffer;

  if (key is String) {
    keyBuffer = Uint8List.fromList(utf8.encode(key));
  } else if (key is Uint8List) {
    keyBuffer = key;
  } else {
    throw ArgumentError('Invalid key type');
  }

  Uint8List messageBuffer = Uint8List.fromList(utf8.encode(message));

  Hmac hmac = Hmac(sha256, keyBuffer);
  Digest digest = hmac.convert(messageBuffer);

  return Uint8List.fromList(digest.bytes);
}
