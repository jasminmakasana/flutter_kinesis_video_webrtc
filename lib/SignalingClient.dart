import 'package:aws_client/kinesis_video_2017_09_30.dart';
import 'package:aws_kinesis_video_signaling_api/kinesis-video-signaling-2019-12-04.dart'
    as KVSChannels;
import 'package:flutter/foundation.dart';

import 'Utils/encoded_strings_generatore.dart';

/// Initializes the AWS signaling channel for real-time communication.
///
/// This method allows users to input AWS credentials, establishes a signaling
/// channel for communication, and retrieves necessary configurations like
/// the channel endpoint and ICE server configuration for WebRTC.
///
/// AWS credentials include Access Key ID, Secret Access Key, and optional
/// Session Token for temporary access to AWS services.
///
/// The signaling channel facilitates real-time communication by enabling
/// signaling between peers, allowing them to exchange information required
/// to establish WebRTC connections.
///
/// The method retrieves the signaling channel endpoint, which serves as the
/// entry point for connecting to the signaling service. Additionally, it fetches
/// ICE (Interactive Connectivity Establishment) server configurations,
/// essential for establishing peer-to-peer WebRTC connections by providing
/// network information like IP addresses and transport protocols.
///
/// After successful initialization, this method stores the signed headers
/// required for establishing a WebSocket connection using the obtained
/// signaling channel endpoint and AWS credentials.
///
/// Example usage:
/// ```dart
/// _signalingClient = SignalingClient(
///         channelName: YOUR_CHANNEL_NAME,
///         accessKey: YOUR_ACCESS_KEY,
///         secretKey: YOUR_SECRET_KEY,
///         region: YOUR_REGION,
///  );
/// ```
///
/// Throws an `AwsCredentialsException` if the provided AWS credentials are invalid
/// or authentication fails. Throws a `SignalingChannelException` if there's an
/// issue establishing or retrieving the signaling channel.
class SignalingClient {
  String accessKey;
  String secretKey;
  String region;
  String channelName;
  String? clientId;
  int expires;

  SignalingClient({
    required this.channelName,
    this.clientId,
    required this.accessKey,
    required this.secretKey,
    required this.region,
    this.expires = 299,
  });

  List<Map<String, dynamic>>? iceServers;
  Map<String, dynamic>? signedQueryParams;
  String? domain;

  /// after Initializes the AWS signaling channel for real-time communication.
  /// call init method of this Signaling Client for get [signedQueryParams]
  /// Example usage:
  /// ```dart
  /// await _signalingClient.init();
  /// ```
  init() async {
    clientId ??= getRandomClientId();
    String channelARN;

    AwsClientCredentials awsCredentials = AwsClientCredentials(
      accessKey: accessKey,
      secretKey: secretKey,
    );

    KinesisVideo kinesisVideoClient = KinesisVideo(
      region: region,
      credentials: awsCredentials,
    );

    DescribeSignalingChannelOutput describeSignalingChannelOutput =
        await kinesisVideoClient.describeSignalingChannel(
            channelName: channelName);

    if (kDebugMode) {
      print(
          "-----channel ARN----->${describeSignalingChannelOutput.channelInfo?.channelARN}");
    }
    channelARN = describeSignalingChannelOutput.channelInfo?.channelARN ?? '';

    GetSignalingChannelEndpointOutput getSignalingChannelEndpointOutput =
        await kinesisVideoClient.getSignalingChannelEndpoint(
      channelARN: channelARN,
      singleMasterChannelEndpointConfiguration:
          SingleMasterChannelEndpointConfiguration(
        role: ChannelRole.viewer,
        protocols: [ChannelProtocol.https, ChannelProtocol.wss],
      ),
    );

    if (kDebugMode) {
      print(
          "-----channel endPoint----->${getSignalingChannelEndpointOutput.resourceEndpointList?.first.resourceEndpoint}");
    }
    domain = getSignalingChannelEndpointOutput.resourceEndpointList
            ?.firstWhere((element) => element.protocol == ChannelProtocol.wss)
            .resourceEndpoint
            ?.substring(6) ??
        "";

    KVSChannels.KinesisVideoSignalingChannels service =
        KVSChannels.KinesisVideoSignalingChannels(
      region: region,
      credentials: KVSChannels.AwsClientCredentials(
        accessKey: accessKey,
        secretKey: secretKey,
      ),
      endpointUrl: getSignalingChannelEndpointOutput.resourceEndpointList
          ?.firstWhere((element) => element.protocol == ChannelProtocol.https)
          .resourceEndpoint,
    );

    KVSChannels.GetIceServerConfigResponse iceOutput =
        await service.getIceServerConfig(
      channelARN: describeSignalingChannelOutput.channelInfo?.channelARN ?? "",
      clientId: clientId,
    );

    iceServers = [
      {"urls": "stun:stun.kinesisvideo.$region.amazonaws.com:443"}
    ];

    iceOutput.iceServerList?.forEach((element) {
      iceServers!.add({
        "urls": element.uris,
        "username": element.username,
        "credential": element.password
      });
    });

    String dateString = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'\.\d{3}Z$'), 'Z')
        .replaceAll(RegExp(r'[:\-]'), "")
        .substring(0, 8);

    String dateTimeString = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'\.\d{6}Z$'), 'Z')
        .replaceAll(RegExp(r'[:\-]'), "");

    Map<String, dynamic> queryParams = {
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-ChannelARN': channelARN,
      'X-Amz-ClientId': clientId,
      'X-Amz-Credential':
          '$accessKey/$dateString/$region/kinesisvideo/aws4_request',
      'X-Amz-Date': dateTimeString,
      'X-Amz-Expires': expires.toString(),
      'X-Amz-SignedHeaders': ['host'].join(';'),
    };

    Uint8List signingKey =
        await getSignatureKey(dateString, secretKey, region, "kinesisvideo");
    String stringToSign = [
      "AWS4-HMAC-SHA256",
      dateTimeString,
      "$dateString/$region/kinesisvideo/aws4_request",
      sha([
        "GET",
        "/",
        createQueryString(queryParams),
        "host:$domain\n",
        ['host'].join(';'),
        await sha('')
      ].join('\n'))
    ].join('\n');

    String signature = toHex((await hmac(signingKey, stringToSign)).buffer);

    queryParams['X-Amz-Signature'] = signature;

    signedQueryParams = queryParams;
  }
}
